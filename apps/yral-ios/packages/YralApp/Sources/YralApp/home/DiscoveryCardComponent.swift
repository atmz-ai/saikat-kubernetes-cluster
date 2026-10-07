import SwiftUI

/// A single draggable influencer card for the discovery deck. The card
/// owns only the transient drag offset and opacity; committing a swipe is
/// the parent's decision — it reports the direction and resets itself.
///
/// The card is a full-bleed COVER: the avatar fills the whole surface and
/// the identity details sit on a legibility gradient at the bottom, so
/// the deck reads as one immersive image rather than a bordered tile.
struct DiscoveryCardComponent: View {
  let influencer: DiscoveryInfluencer
  let onSwipe: (SwipeDirection) -> Void

  @State private var dragOffset: CGSize = .zero

  enum SwipeDirection {
    case left  // reject
    case right  // match
    case up  // next
    case down  // previous
  }

  /// Fraction of the card the user must drag before it commits. Measured
  /// against the card's own size, so the gesture feels the same on every
  /// device rather than needing a pixel threshold per screen.
  private let commitFraction: CGFloat = 0.28

  var body: some View {
    GeometryReader { geometry in
      card
        .offset(dragOffset)
        .rotationEffect(.degrees(Double(dragOffset.width / geometry.size.width) * 6))
        .gesture(dragGesture(in: geometry.size))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .accessibilityIdentifier("home.card.\(influencer.id)")
    }
  }

  private var card: some View {
    ZStack(alignment: .bottomLeading) {
      coverImage
      // Bottom-anchored gradient so the white text stays legible over any
      // image. Clear at the top keeps the image itself unmodified.
      LinearGradient(
        colors: [.clear, .clear, .black.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
      )
      details
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(alignment: .topLeading) { stamp("NOPE", color: .red, visible: dragOffset.width < -40) }
    .overlay(alignment: .topTrailing) {
      stamp("MATCH", color: .green, visible: dragOffset.width > 40)
    }
    .shadow(radius: 12)
  }

  private var coverImage: some View {
    AsyncImage(url: influencer.avatarURL.flatMap(URL.init(string:))) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFill()
      default:
        ZStack {
          Color.gray.opacity(0.25)
          Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .padding(80)
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(influencer.displayName)
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .accessibilityIdentifier("home.card.\(influencer.id).name")
      Text("@\(influencer.username)")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.85))
      if let description = influencer.description {
        Text(description)
          .font(.body)
          .foregroundStyle(.white.opacity(0.9))
          .lineLimit(3)
          .padding(.top, 2)
      }
    }
    .padding(28)
    // Clear the floating action row (buttons sit ~96-160pt from the
    // bottom) so the name + description never sit behind the buttons.
    .padding(.bottom, 176)
  }

  private func stamp(_ text: String, color: Color, visible: Bool) -> some View {
    Text(text)
      .font(.title.bold())
      .foregroundStyle(color)
      .padding(8)
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
      .rotationEffect(.degrees(text == "NOPE" ? -15 : 15))
      .padding(24)
      .opacity(visible ? 1 : 0)
  }

  private func dragGesture(in size: CGSize) -> some Gesture {
    DragGesture()
      .onChanged { value in
        dragOffset = value.translation
      }
      .onEnded { value in
        let horizontal = value.translation.width
        let vertical = value.translation.height
        let commitX = size.width * commitFraction
        let commitY = size.height * commitFraction

        // Horizontal intent wins when it dominates the vertical — a
        // diagonal gesture should read as left/right, not up/down.
        if abs(horizontal) > abs(vertical), abs(horizontal) > commitX {
          reset()
          onSwipe(horizontal > 0 ? .right : .left)
        } else if abs(vertical) > commitY {
          reset()
          onSwipe(vertical < 0 ? .up : .down)
        } else {
          reset()
        }
      }
  }

  private func reset() {
    dragOffset = .zero
  }
}
