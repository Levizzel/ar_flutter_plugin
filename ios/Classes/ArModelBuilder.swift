import UIKit
import Foundation
import ARKit
import SpriteKit
import GLTFSceneKit
import Combine

// Responsible for creating Renderables and Nodes
class ArModelBuilder: NSObject {

    func makePlane(anchor: ARPlaneAnchor, flutterAssetFile: String?) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        //Create material
        let material = SCNMaterial()
        let opacity: CGFloat
        
        if let textureSourcePath = flutterAssetFile {
            // Use given asset as plane texture
            let key = FlutterDartProject.lookupKey(forAsset: textureSourcePath)
            if let image = UIImage(named: key, in: Bundle.main,compatibleWith: nil){
                // Asset was found so we can use it
                material.diffuse.contents = image
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                plane.materials = [material]
                opacity = 1.0
            } else {
                // Use standard planes
                opacity = 0.3
            }
        } else {
            // Use standard planes
            opacity = 0.3
        }
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
        // rotate plane by 90 degrees to match the anchor (planes are vertical by default)
        planeNode.eulerAngles.x = -.pi / 2

        planeNode.opacity = opacity

        return planeNode
    }

    func updatePlaneNode(planeNode: SCNNode, anchor: ARPlaneAnchor){
        if let plane = planeNode.geometry as? SCNPlane {
            // Update plane dimensions
            plane.width = CGFloat(anchor.extent.x)
            plane.height = CGFloat(anchor.extent.z)
            // Update texture of planes
            let imageSize: Float = 65 // in mm
            let repeatAmount: Float = 1000 / imageSize //how often per meter we need to repeat the image
            if let gridMaterial = plane.materials.first {
                gridMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(anchor.extent.x * repeatAmount, anchor.extent.z * repeatAmount, 1)
            }
        }
       planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
    }

    // Creates a node from a given gltf2 (.gltf) model in the Flutter assets folder
    func makeNodeFromGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(named: modelPath)
            scene = try sceneSource.scene()

            for child in scene.rootNode.childNodes {
                child.scale = SCNVector3(0.01,0.01,0.01) // Compensate for the different model dimension definitions in iOS and Android (meters vs. millimeters)
                //child.eulerAngles.z = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                //child.eulerAngles.y = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            if let transform = transformation {
                node.transform = deserializeMatrix4(transform)
            }

            return node
        } catch {
            print("\(error.localizedDescription)")
            return nil
        }
    }

    // Creates a node from a given gltf2 (.gltf) model in the Flutter assets folder
    func makeNodeFromFileSystemGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()

            for child in scene.rootNode.childNodes {
                child.scale = SCNVector3(0.01,0.01,0.01) // Compensate for the different model dimension definitions in iOS and Android (meters vs. millimeters)
                //child.eulerAngles.z = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                //child.eulerAngles.y = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            if let transform = transformation {
                node.transform = deserializeMatrix4(transform)
            }

            return node
        } catch {
            print("\(error.localizedDescription)")
            return nil
        }
    }
    
    // Creates a node from a given glb model in the app's documents directory
    func makeNodeFromText(name: String, text: String, transformation: Array<NSNumber>?) -> SCNNode? {

        let textGeometry: SCNText = SCNText(string: text, extrusionDepth: 0.14)
        textGeometry.font = UIFont(name: "Optima", size: 0.5) 
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.2588, blue: 0.2588, alpha: 1.0)
        textGeometry.materials = [material]
        let textNode = SCNNode(geometry: textGeometry)
        
        let (min, max) = textNode.boundingBox

        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        
        let node: SCNNode = SCNNode()
        node.addChildNode(textNode)
        node.name = name
        if let transform = transformation {
            node.transform = deserializeMatrix4(transform)
        }
        return node
    }

    func makeNodeFromImage(name: String, assetPath: String, transformation: Array<NSNumber>?) -> SCNNode? {

        let uiImage = UIImage(contentsOfFile: assetPath)    
        let material = SCNMaterial()
        if let image = uiImage {
            let planeGeometry = SCNPlane(width: image.size.width, height: image.size.height)
            material.isDoubleSided = true
            material.diffuse.contents = image
            planeGeometry.materials = [material]
            
            let geometryNode = SCNNode(geometry: planeGeometry)
            geometryNode.scale = SCNVector3(0.0025, 0.0025, 0.0025)
            
            // wrapperNode is needed so that transformation of node can be safely done and does not effect the plane geometry
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(geometryNode)
            wrapperNode.name = name 
            if let transform = transformation {
                wrapperNode.transform = deserializeMatrix4(transform)
            }

            return wrapperNode
        }
        return nil
    }

    func makeNodeFromVideo(name: String, skVideoNode: SKVideoNode, transformation: Array<NSNumber>?) -> SCNNode? {

            let node = SCNNode()
            let videoNode = skVideoNode

            let videoScene = SKScene(size: CGSize(width: 1920, height: 1080))

            videoScene.addChild(videoNode)

            let plane = SCNPlane(width: 3, height: 3 * 1080 / 1920)

            videoNode.position = CGPoint(x: videoScene.size.width/2, y: videoScene.size.height/2)
            videoNode.yScale = -1.0
            plane.firstMaterial?.diffuse.contents = videoScene
            plane.firstMaterial?.isDoubleSided = true

            let planeNode = SCNNode(geometry: plane)

            node.addChildNode(planeNode)
            node.name = name
            if let transform = transformation {
                node.transform = deserializeMatrix4(transform)
            }
            return node
       
    }
    
    // Creates a node from a given glb model in the app's documents directory
    func makeNodeFromFileSystemGLB(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {

       
        var scene: SCNScene
        let node: SCNNode = SCNNode()
        
        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()

            for child in scene.rootNode.childNodes {
                //child.scale = SCNVector3(0.01,0.01,0.01) // Compensate for the different model dimension definitions in iOS and Android (meters vs. millimeters)
                //child.eulerAngles.z = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                //child.eulerAngles.y = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            if let transform = transformation {
                node.transform = deserializeMatrix4(transform)
            }

            return node
        } catch {
            print("\(error.localizedDescription)")
            return nil
        }
    }
    
    // Creates a node form a given glb model path
    func makeNodeFromWebGlb(name: String, modelURL: String, transformation: Array<NSNumber>?) -> Future<SCNNode?, Never> {
        
        return Future {promise in
            var node: SCNNode? = SCNNode()
            
            let handler: (URL?, URLResponse?, Error?) -> Void = {(url: URL?, urlResponse: URLResponse?, error: Error?) -> Void in
                // If response code is not 200, link was invalid, so return
                if ((urlResponse as? HTTPURLResponse)?.statusCode != 200) {
                    print("makeNodeFromWebGltf received non-200 response code")
                    node = nil
                    promise(.success(node))
                } else {
                    guard let fileURL = url else { return }
                    do {
                        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        let documentsDirectory = paths[0]
                        let targetURL = documentsDirectory.appendingPathComponent(urlResponse!.url!.lastPathComponent)
                        
                        try? FileManager.default.removeItem(at: targetURL) //remove item if it's already there
                        try FileManager.default.copyItem(at: fileURL, to: targetURL)

                        do {
                            let sceneSource = GLTFSceneSource(url: targetURL)
                            let scene = try sceneSource.scene()

                            for child in scene.rootNode.childNodes {
                                child.scale = SCNVector3(0.01,0.01,0.01) // Compensate for the different model dimension definitions in iOS and Android (meters vs. millimeters)
                                //child.eulerAngles.z = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                                //child.eulerAngles.y = -.pi // Compensate for the different model coordinate definitions in iOS and Android
                                node?.addChildNode(child)
                            }

                            node?.name = name
                            if let transform = transformation {
                                node?.transform = deserializeMatrix4(transform)
                            }
                            /*node?.scale = worldScale
                            node?.position = worldPosition
                            node?.worldOrientation = worldRotation*/

                        } catch {
                            print("\(error.localizedDescription)")
                            node = nil
                        }
                        
                        // Delete file to avoid cluttering device storage (at some point, caching can be included)
                        try FileManager.default.removeItem(at: targetURL)
                        
                        promise(.success(node))
                    } catch {
                        node = nil
                        promise(.success(node))
                    }
                }
                
            }
            
    
            let downloadTask = URLSession.shared.downloadTask(with: URL(string: modelURL)!, completionHandler: handler)
            
            downloadTask.resume()
            
        }
        
    }
    
}
