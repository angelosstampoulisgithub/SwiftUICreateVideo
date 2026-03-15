//
//  VideoGenerator.swift
//  SwiftUICreateVideo
//
//  Created by Angelos Staboulis on 14/3/26.
//

import Foundation
import AVFoundation
import UIKit

func createAdvancedVideo(
    images: [UIImage],
    outputURL: URL,
    durationPerImage: Double,
    size: CGSize,
    musicURL: URL?,
    progress: @escaping (Double) -> Void
) async throws {

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height
    ]

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let fps: Int32 = 30
    let totalFrames = Int(Double(images.count) * durationPerImage * Double(fps))
    var frameCount: Int64 = 0

    for (index, img) in images.enumerated() {
        let nextImage = index < images.count - 1 ? images[index + 1] : img

        for i in 0..<(Int(durationPerImage * Double(fps))) {
            let t = Double(i) / (durationPerImage * Double(fps))

            let buffer = pixelBuffer(from: nextImage, size: size)!
            while !input.isReadyForMoreMediaData { await Task.yield() }

            let time = CMTime(value: frameCount, timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)

            frameCount += 1
            progress(Double(frameCount) / Double(totalFrames))
        }
    }

    input.markAsFinished()
    await writer.finishWriting()

  
}

func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
    let attrs = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ] as CFDictionary

    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                        kCVPixelFormatType_32ARGB, attrs, &buffer)

    guard let pixelBuffer = buffer else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixelBuffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    )

    if let cgImage = image.cgImage {
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    return pixelBuffer
}
