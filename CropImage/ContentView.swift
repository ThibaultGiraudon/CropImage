//
//  ContentView.swift
//  CropImage
//
//  Created by Thibault Giraudon on 31/08/2024.
//

import SwiftUI
import PhotosUI

struct ResultView: View {
	var uiImage: UIImage?
	var body: some View {
		Image(uiImage: uiImage!)
			.resizable()
			.scaledToFit()
	}
}

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
						toRect:
							CGRect(
								x: (((imageViewSize.width) - (mask.width / scale)) / 2 - offset.width / scale),
								y: (((imageViewSize.height) - (mask.height / scale)) / 2 - offset.height / scale),
								width: mask.width / scale,
								height: mask.height / scale),
						viewWidth: UIScreen.main.bounds.width,
						viewHeight: UIScreen.main.bounds.height)
				}) {
					Image(systemName: "checkmark.circle")
				}
			}
		}
		.onChange(of: croppedImage) {
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
		let imageViewScale = max(inputImage.size.width / viewWidth,
								 inputImage.size.height / viewHeight)
        
        var cropZone: CGRect
        
        if inputImage.imageOrientation == .right {
            cropZone = CGRect(x: cropRect.origin.y * imageViewScale,
                              y: cropRect.origin.x * imageViewScale,
                              width: cropRect.size.height * imageViewScale,
                              height: cropRect.size.width * imageViewScale)
        } else if inputImage.imageOrientation == .down {
            cropZone = CGRect(x: inputImage.size.width - (cropRect.origin.x * imageViewScale),
                              y: inputImage.size.height - (cropRect.origin.y * imageViewScale),
                              width: -cropRect.size.width * imageViewScale,
                              height: -cropRect.size.height * imageViewScale)
        } else {
            cropZone = CGRect(x: cropRect.origin.x * imageViewScale,
                              y: cropRect.origin.y * imageViewScale,
                              width: cropRect.size.width * imageViewScale,
                              height: cropRect.size.height * imageViewScale)
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
                            selectedItem = nil
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

#Preview {
	NavigationStack {
		ContentView()
	}
}

