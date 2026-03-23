import SwiftUI

// MARK: - Star Rating View
struct StarRatingView: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 16
    var color: Color = .yellow
    var interactive: Bool = false
    var onRatingChanged: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? color : Color(.systemGray4))
                    .onTapGesture {
                        if interactive {
                            onRatingChanged?(star)
                        }
                    }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        StarRatingView(rating: 3)
        StarRatingView(rating: 5, color: .orange)
        StarRatingView(rating: 1, size: 24, color: .red)
    }
    .padding()
}
