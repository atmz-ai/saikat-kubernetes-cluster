# Final Legacy API DNS Retirement

Run only after every client and serving certificate has completed cutover.
The role deletes A records for the single retired Cloudflare API hostname;
it does not delete zones, wildcard records, or credentials. PowerDNS record
retirement remains owned by generated DNSEndpoints and Flux pruning.
