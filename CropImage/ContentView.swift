//
//  ContentView.swift
//  CropImage
//
//  Created by Thibault Giraudon on 31/08/2024.
//

import SwiftUI

struct CropImageView: View {
	var offset: CGSize
	var scale: CGFloat
	@State var imageViewSize: CGSize
	@State var uiImage: UIImage? = UIImage(named: "m4")
	let factor = UIScreen.main.bounds.width / UIImage(named: "m4")!.size.width
	var body: some View {
		Image(uiImage: uiImage!)
			.resizable()
			.scaledToFit()
			.onAppear {
				imageViewSize.height = UIImage(named: "m4")!.size.height * factor
				imageViewSize.width = UIImage(named: "m4")!.size.width * factor
				uiImage = cropImage(
					uiImage!,
						toRect:
							CGRect(
								x: (((imageViewSize.width) - (300 / scale)) / 2 - offset.width / scale),
								y: (((imageViewSize.height) - (225 / scale)) / 2 - offset.height / scale),
								width: 300 / scale,
								height: 225 / scale),
						viewWidth: UIScreen.main.bounds.width,
						viewHeight: UIScreen.main.bounds.height)
			}
	}
	
	func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
		let imageViewScale = max(inputImage.size.width / viewWidth,
								 inputImage.size.height / viewHeight)
		
		// Scale cropRect to handle images larger than shown-on-screen size
		let cropZone = CGRect(x: cropRect.origin.x * imageViewScale,
							  y: cropRect.origin.y * imageViewScale,
							  width: cropRect.size.width * imageViewScale,
							  height: cropRect.size.height * imageViewScale)
		
		// Perform cropping in Core Graphics
		guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to: cropZone) else {
			return nil
		}
		
		// Return image to UIImage
		let croppedImage: UIImage = UIImage(cgImage: cutImageRef)
		return croppedImage
	}
}

struct ContentView: View {
	@State private var offsetLimit: CGSize = .zero
	@State private var offset = CGSize.zero
	@State private var lastOffset: CGSize = .zero
	@State private var showSheet: Bool = false
	@State private var scale: CGFloat = 1
	@State private var lastScale: CGFloat = 0
	@State private var imageViewSize: CGSize = .zero
	let factor = UIScreen.main.bounds.width / UIImage(named: "m4")!.size.width
	var body: some View {
		
		let dragGeometry = DragGesture()
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
				scale = min(max(scaledValue * lastScale, 300 / imageViewSize.width), 5)
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
				Image("m4")
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

			Image("m4")
				.resizable()
				.scaledToFit()
				.scaleEffect(scale)
				.offset(offset)
				.mask(
					Rectangle()
						.frame(width: 300, height: 225)
				)
				.overlay {
					Rectangle()
						.stroke(Color.white, lineWidth: 1)
						.frame(width: 300, height: 225)
				}
		}
		.simultaneousGesture(dragGeometry)
		.simultaneousGesture(scaleGesture)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button(action: {
					showSheet = true
				}) {
					Image(systemName: "checkmark.circle")
				}
			}
		}
		.sheet(isPresented: $showSheet) {
			CropImageView(offset: offset, scale: scale, imageViewSize: imageViewSize)
		}
		.onAppear {
			imageViewSize.height = UIImage(named: "m4")!.size.height * factor
			imageViewSize.width = UIImage(named: "m4")!.size.width * factor
		}
	}
	
	func getOffsetLimit() -> CGSize {
		var offsetLimit: CGSize = .zero
		offsetLimit.width = ((imageViewSize.width * scale) - 300) / 2
		offsetLimit.height = ((imageViewSize.height * scale) - 225) / 2
		return offsetLimit
	}
	
}

#Preview {
	NavigationStack {
		ContentView()
	}
}

