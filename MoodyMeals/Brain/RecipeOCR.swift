import Foundation
import Vision
import UIKit

// ── Recipe import via photos/screenshots — on-device Vision OCR ──────
// One or more photos in, one text block out, fed straight into the same
// `MoodyBrain.parseRecipe(from:)` a typed paste already uses — a
// photographed recipe carries the exact same guarantees (NL-7/NL-8,
// notCheckedYet default, gluten-carrier flagging) as typing it in.
// On-device only: nothing about the photo itself leaves the phone: only
// the recognized text goes to the parse call afterward.

enum RecipeOCR {
    enum OCRError: Error, Equatable {
        case noText          // recognized nothing across every image
        case decodeFailed    // image data didn't decode
    }

    /// Recognizes text in each image (in the order given) and joins the
    /// results into one block — a multi-photo recipe (several screenshots
    /// of one page, or a few cookbook-spread photos) reads as continuous
    /// text, the same shape a typed paste already is.
    static func recognizedText(fromImageData datas: [Data]) async throws -> String {
        var blocks: [String] = []
        for data in datas {
            guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                continue
            }
            let text = try await recognizedText(in: cgImage)
            if !text.isEmpty { blocks.append(text) }
        }
        guard !blocks.isEmpty else { throw OCRError.noText }
        return blocks.joined(separator: "\n\n")
    }

    private static func recognizedText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
