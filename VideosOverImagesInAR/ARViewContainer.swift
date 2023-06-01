//
//  ARViewContainer.swift
//  AR
//
//  Created by Can Göktas on 16.02.23.
//

import ARKit
import AVKit
import RealityKit
import SwiftUI

struct ARViewContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ARViewRepresentable()
            content
        }
    }
}

private struct ARViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = context.coordinator.createARView()

        // Configure image detection for the current ARView using the following
        // images and their physical widths in meters (height is calculated by
        // the framework based on the image's aspect ratio).
        let referenceNameWidthPairs = [
            ("image-0", 0.1),
            // Add more images to detect here
        ]
        var referenceImages = Set<ARReferenceImage>()
        referenceNameWidthPairs.forEach { name, width in
            let referenceImage = ARReferenceImage(
                UIImage(named: name)!.cgImage!,
                orientation: .up,
                physicalWidth: width
            )
            referenceImage.name = name
            referenceImages.insert(referenceImage)
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1
        arView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )

        return arView
    }

    func updateUIView(_: ARView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        private var arView: ARView!
        private var playingResource: String?
        private var playerItemPlayerPairByResource =
            [String: (AVPlayerItem, AVPlayer)]()

        func createARView() -> ARView {
            arView = ARView(frame: .zero)
            arView.session.delegate = self
            return arView
        }

        func session(_: ARSession, didUpdate _: ARFrame) {}
        func session(_: ARSession, didAdd anchors: [ARAnchor]) {
            guard let imageAnchor = anchors.first as? ARImageAnchor else {
                return
            }
            let detectedResource = imageAnchor.referenceImage.name!

            let playerItem: AVPlayerItem
            let player: AVPlayer
            if playerItemPlayerPairByResource[detectedResource] != nil {
                playerItem = playerItemPlayerPairByResource[detectedResource]!.0
                player = playerItemPlayerPairByResource[detectedResource]!.1
            } else {
                playerItem = AVPlayerItem(url: Bundle.main.url(
                    forResource: imageAnchor.referenceImage.name!,
                    withExtension: "mp4"
                )!)
                player = AVPlayer(playerItem: playerItem)
            }
            playerItemPlayerPairByResource[detectedResource] = (playerItem,
                                                                player)

            if playingResource != nil {
                // If we were already playing the video of another detected
                // image, stop playing it
                let (playerItem,
                     player) = playerItemPlayerPairByResource[playingResource!]!
                player.pause()
                playerItem.seek(to: .zero, completionHandler: nil)
            }

            let videoMaterial = VideoMaterial(avPlayer: player)
            videoMaterial.controller.audioInputMode = .spatial

            let modelEntity = ModelEntity(
                mesh: MeshResource.generatePlane(
                    width: Float(imageAnchor.referenceImage.physicalSize.width),
                    height: Float(imageAnchor.referenceImage.physicalSize
                        .height)
                ),
                materials: [videoMaterial]
            )
            // By default, the plane will be placed perpendicular to the image
            // anchor. We rotate the x-axis of the plane by 90 degrees to place
            // it parallel to the detected image, right on top of it
            // (from this: __|__ to this =====).
            modelEntity.transform.rotation = simd_quatf(
                angle: -.pi / 2, // -90 degrees
                axis: SIMD3<Float>(1, 0, 0) // only x-axis
            )

            let anchorEntity = AnchorEntity(anchor: imageAnchor)
            anchorEntity.addChild(modelEntity)

            arView.scene.addAnchor(anchorEntity)

            player.play()
            playingResource = detectedResource
        }

        func session(_: ARSession, didUpdate _: [ARAnchor]) {}
    }
}
