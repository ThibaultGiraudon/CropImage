
# SwiftUI Image Cropper

This project demonstrates how to pick an image from your photo gallery and crop it to a defined size using SwiftUI. The app utilizes Swift and SwiftUI frameworks, making it a great example for developers looking to implement image cropping functionalities in their iOS applications.

## Prerequisites

- Basic knowledge of Swift and SwiftUI.
- Xcode installed on your Mac.

## Features

- Pick an image from the photo gallery.
- Crop the selected image to a specific size.
- Drag and scale the image to adjust the crop area.
- Supports fixing the orientation of the cropped image.

## Getting Started

### Step 1: Build the `ContentView`

The `ContentView` is the main view where the user can pick an image and see the selected image.

```swift
import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showSheet = false

    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            PhotosPicker(selection: $selectedItem) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Pick an image")
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try await selectedItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            showSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showSheet) {
                if let image = selectedImage {
                    NavigationStack {
                        CropImageView(uiImage: image) { cropImage in
                            selectedImage = cropImage
                        }
                    }
                }
            }
        }
    }
}
```

### Step 2: Build the `CropImageView`

The `CropImageView` allows users to crop the selected image by dragging and scaling the image to fit within a defined mask.

```swift
struct CropImageView: View {
    var uiImage: UIImage
    var save: (UIImage?) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var offsetLimit: CGSize = .zero
    @State private var offset = CGSize.zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 0
    @State private var imageViewSize: CGSize = .zero
    @State private var croppedImage: UIImage?
    let mask = CGSize(width: 300, height: 225)

    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { gesture in
                offsetLimit = getOffsetLimit()

                let width = min(
                    max(-offsetLimit.width, lastOffset.width + gesture.translation.width),
                    offsetLimit.width
                )
                let height = min(
                    max(-offsetLimit.height, lastOffset.height + gesture.translation.height),
                    offsetLimit.height
                )

                offset = CGSize(width: width, height: height)
            }
            .onEnded { value in
                lastOffset = offset
            }

        let scaleGesture = MagnifyGesture()
            .onChanged { gesture in
                let scaledValue = (gesture.magnification - 1) * 0.5 + 1
                scale = min(max(scaledValue * lastScale, max(mask.width / imageViewSize.width, mask.height / imageViewSize.height)), 5)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }

        ZStack(alignment: .center) {
            ZStack {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .ignoresSafeArea()
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
            }
            .blur(radius: 20)

            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .mask(
                    Rectangle()
                        .frame(width: mask.width, height: mask.height)
                )
                .overlay {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1)
                        .frame(width: mask.width, height: mask.height)
                }
        }
        .simultaneousGesture(dragGesture)
        .simultaneousGesture(scaleGesture)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    croppedImage = cropImage(
                        uiImage,
                        toRect: CGRect(
                            x: (((imageViewSize.width) - (mask.width / scale)) / 2 - offset.width / scale),
                            y: (((imageViewSize.height) - (mask.height / scale)) / 2 - offset.height / scale),
                            width: mask.width / scale,
                            height: mask.height / scale
                        ),
                        viewWidth: UIScreen.main.bounds.width,
                        viewHeight: UIScreen.main.bounds.height
                    )
                }) {
                    Image(systemName: "checkmark.circle")
                }
            }
        }
        .onChange(of: croppedImage) { _ in
            save(croppedImage)
            dismiss()
        }
        .onAppear {
            let factor = UIScreen.main.bounds.width / uiImage.size.width
            imageViewSize.height = uiImage.size.height * factor
            imageViewSize.width = uiImage.size.width * factor
        }
    }

    func getOffsetLimit() -> CGSize {
        var offsetLimit: CGSize = .zero
        offsetLimit.width = ((imageViewSize.width * scale) - mask.width) / 2
        offsetLimit.height = ((imageViewSize.height * scale) - mask.height) / 2
        return offsetLimit
    }

    func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
        let imageViewScale = max(inputImage.size.width / viewWidth, inputImage.size.height / viewHeight)

        var cropZone: CGRect

        if inputImage.imageOrientation == .right {
            cropZone = CGRect(
                x: cropRect.origin.y * imageViewScale,
                y: cropRect.origin.x * imageViewScale,
                width: cropRect.size.height * imageViewScale,
                height: cropRect.size.width * imageViewScale
            )
        } else if inputImage.imageOrientation == .down {
            cropZone = CGRect(
                x: inputImage.size.width - (cropRect.origin.x * imageViewScale),
                y: inputImage.size.height - (cropRect.origin.y * imageViewScale),
                width: -cropRect.size.width * imageViewScale,
                height: -cropRect.size.height * imageViewScale
            )
        } else {
            cropZone = CGRect(
                x: cropRect.origin.x * imageViewScale,
                y: cropRect.origin.y * imageViewScale,
                width: cropRect.size.width * imageViewScale,
                height: cropRect.size.height * imageViewScale
            )
        }

        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to: cropZone) else {
            return nil
        }

        // Return image to UIImage
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)

        return croppedImage.fixOrientation(og: inputImage)
    }
}
```

### Step 3: Build the `UIImage` Extension

This extension helps fix the orientation of an `UIImage` after cropping.

```swift
public extension UIImage {
    /// Extension to fix orientation of an UIImage without EXIF
    func fixOrientation(og: UIImage) -> UIImage {
        switch og.imageOrientation {
        case .up:
            return self
        case .down:
            return UIImage(cgImage: cgImage!, scale: scale, orientation: .down)
        case .left:
            return UIImage(cgImage: cgImage!, scale: scale, orientation: .left)
        case .right:
            return UIImage(cgImage: cgImage!, scale: scale, orientation: .right)
        case .upMirrored:
            return self
        case .downMirrored:
            return self
        case .leftMirrored:
            return self
        case .rightMirrored:
            return self
        @unknown default:
            return self
        }
    }
}
```

## Step 4: Understanding the Code

### State Properties :

- `offset`: Controls the current position of the image.
- `lastOffset`: Controls the last position of the image while moving it.
- `offsetLimit`: Controls the maximum and minimum offset the image can move.
- `scale`: Controls the zoom effect of the image.
- `lastScale`: Controls the last scale of the image while zooming it.
- `imageViewSize`: Represents the current image size on the screen.
- `croppedImage`: Contains the image after cropping.

### Gestures :

- **DragGesture**: Allows the user to drag the image horizontally and vertically.
- **MagnifyGesture**: Allows the user to pinch the image to zoom in or out.

### Math :

- **Factor Calculation**: 
  ```swift
  factor = UIScreen.main.bounds.width / uiImage.size.width
  ```
  This helps in determining the size of the image view relative to the screen width.

- **Offset Calculation**:
  ```swift
  offsetLimit.width = ((imageViewSize.width * scale) — mask.width) / 2
  ```
  This calculates how much the user can move the image.

- **Crop Origin Calculation**:
  ```swift
  (((imageViewSize.width) — (mask.width / scale)) / 2 — offset.width / scale)
  ```
  This gives the starting point of the cropping area, considering the scale effect and the movement offset.

### Extension

When an `UIImage` is transformed into a `CGImage`, some information like the orientation is lost. The `fixOrientation` function helps in adjusting the orientation of the cropped image.

## Conclusion

You’ve successfully built a SwiftUI app that can crop gallery images. This functionality is a great addition to any app that needs to manage images while respecting a certain scale.

Feel free to customize and extend the functionality according to your app's requirements.
