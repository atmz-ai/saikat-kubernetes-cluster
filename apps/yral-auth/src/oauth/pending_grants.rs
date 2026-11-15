use std::{collections::HashMap, sync::Mutex};

use sha2::{Digest, Sha256};

/// ! Issued grants exist only in this process; removal is terminal and atomic.
#[derive(Default)]
pub struct PendingGrants {
    issued: Mutex<HashMap<[u8; 32], usize>>,
}

impl PendingGrants {
    pub fn issue(&self, token: &str, expires_at: usize, now: usize) -> Result<(), String> {
        if expires_at <= now {
            return Err("Cannot issue an expired grant".to_string());
        }
        let mut issued = self
            .issued
            .lock()
            .map_err(|_| "Grant storage unavailable")?;
        issued.retain(|_, expiry| *expiry > now);
        let fingerprint = Sha256::digest(token.as_bytes()).into();
        if issued.contains_key(&fingerprint) {
            return Err("Grant already issued".to_string());
        }
        issued.insert(fingerprint, expires_at);
        Ok(())
    }

    pub fn consume(&self, token: &str, now: usize) -> Result<bool, String> {
        let mut issued = self
            .issued
            .lock()
            .map_err(|_| "Grant storage unavailable")?;
        let fingerprint: [u8; 32] = Sha256::digest(token.as_bytes()).into();
        let expires_at = issued.remove(&fingerprint);
        issued.retain(|_, expiry| *expiry > now);
        Ok(expires_at.is_some_and(|expiry| expiry > now))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Barrier};

    #[test]
    fn grants_are_one_time_expiring_and_fail_closed_after_restart() {
        let grants = PendingGrants::default();
        grants.issue("code", 20, 10).unwrap();
        assert!(grants.consume("code", 11).unwrap());
        assert!(!grants.consume("code", 11).unwrap());
        assert!(!grants.consume("unknown", 11).unwrap());
        grants.issue("expired", 20, 10).unwrap();
        assert!(!grants.consume("expired", 20).unwrap());
        assert!(grants.issue("already-expired", 10, 10).is_err());
        grants.issue("pending", 20, 10).unwrap();
        assert!(grants.issue("pending", 30, 10).is_err());
        assert!(!PendingGrants::default().consume("pending", 11).unwrap());
        assert!(grants.consume("pending", 11).unwrap());
    }

    #[test]
    fn concurrent_redemption_has_exactly_one_winner() {
        let grants = Arc::new(PendingGrants::default());
        grants.issue("same-code", 20, 10).unwrap();
        let barrier = Arc::new(Barrier::new(8));
        let workers = (0..8)
            .map(|_| {
                let grants = Arc::clone(&grants);
                let barrier = Arc::clone(&barrier);
                std::thread::spawn(move || {
                    barrier.wait();
                    usize::from(grants.consume("same-code", 11).unwrap())
                })
            })
            .collect::<Vec<_>>();
        let winners: usize = workers
            .into_iter()
            .map(|worker| worker.join().unwrap())
            .sum();
        assert_eq!(winners, 1);
    }
}
