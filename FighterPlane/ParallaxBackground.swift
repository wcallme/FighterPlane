import SpriteKit

class ParallaxBackground {

    private weak var scene: SKScene?
    private var groundLayers: [(SKSpriteNode, SKSpriteNode)] = []
    private var cloudNodes: [SKSpriteNode] = []
    private var treeClusters: [SKSpriteNode] = []

    // Layer scroll speeds (multipliers of base scroll speed)
    private let groundSpeed: CGFloat = 1.0
    private let detailSpeed: CGFloat = 1.1
    private let cloudSpeed: CGFloat = 0.3

    init(scene: SKScene) {
        self.scene = scene
        setupGround()
        setupClouds()
        setupInitialTrees()
    }

    // MARK: - Setup

    private func setupGround() {
        guard let scene = scene else { return }
        // Create two ground strips that tile vertically for seamless scrolling
        let stripHeight = scene.size.height + 128

        let ground1 = createGroundStrip(
            size: CGSize(width: scene.size.width, height: stripHeight), variant: 0
        )
        ground1.position = CGPoint(x: scene.size.width / 2, y: stripHeight / 2)
        ground1.zPosition = ZLayer.background.rawValue
        scene.addChild(ground1)

        let ground2 = createGroundStrip(
            size: CGSize(width: scene.size.width, height: stripHeight), variant: 2
        )
        ground2.position = CGPoint(x: scene.size.width / 2, y: stripHeight / 2 + stripHeight)
        ground2.zPosition = ZLayer.background.rawValue
        scene.addChild(ground2)

        groundLayers.append((ground1, ground2))
    }

    private func createGroundStrip(size: CGSize, variant: Int) -> SKSpriteNode {
        let node = SKSpriteNode(color: .clear, size: size)

        // Tile the texture across the strip
        let tileW: CGFloat = 128
        let tileH: CGFloat = 128
        let cols = Int(ceil(size.width / tileW))
        let rows = Int(ceil(size.height / tileH))

        for row in 0..<rows {
            for col in 0..<cols {
                let tile = SKSpriteNode(texture: SpriteGenerator.groundTile(variant: variant + row + col))
                tile.size = CGSize(width: tileW, height: tileH)
                tile.position = CGPoint(
                    x: -size.width / 2 + CGFloat(col) * tileW + tileW / 2,
                    y: -size.height / 2 + CGFloat(row) * tileH + tileH / 2
                )
                node.addChild(tile)
            }
        }

        return node
    }

    private func setupClouds() {
        guard let scene = scene else { return }
        let cloudTexture = SpriteGenerator.cloud()
        for _ in 0..<6 {
            let cloud = SKSpriteNode(texture: cloudTexture)
            let scale = CGFloat.random(in: 0.6...1.5)
            cloud.setScale(scale)
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: CGFloat.random(in: 0...scene.size.height)
            )
            cloud.zPosition = ZLayer.clouds.rawValue
            cloud.alpha = CGFloat.random(in: 0.15...0.35)
            scene.addChild(cloud)
            cloudNodes.append(cloud)
        }
    }

    private func setupInitialTrees() {
        guard let scene = scene else { return }
        let treeTexture = SpriteGenerator.treePatch()
        for _ in 0..<12 {
            let tree = SKSpriteNode(texture: treeTexture)
            tree.position = CGPoint(
                x: CGFloat.random(in: 20...(scene.size.width - 20)),
                y: CGFloat.random(in: 0...scene.size.height)
            )
            tree.zPosition = ZLayer.groundDetail.rawValue
            let scale = CGFloat.random(in: 0.7...1.3)
            tree.setScale(scale)
            tree.name = "tree"
            scene.addChild(tree)
            treeClusters.append(tree)
        }
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval) {
        guard let scene = scene else { return }
        let baseScroll = GameConfig.scrollSpeed * CGFloat(deltaTime)

        // Scroll ground layers
        for (ground1, ground2) in groundLayers {
            ground1.position.y -= baseScroll * groundSpeed
            ground2.position.y -= baseScroll * groundSpeed

            let height = ground1.size.height
            // Wrap when off screen
            if ground1.position.y <= -height / 2 {
                ground1.position.y += height * 2
            }
            if ground2.position.y <= -height / 2 {
                ground2.position.y += height * 2
            }
        }

        // Scroll trees (detail layer)
        for tree in treeClusters {
            tree.position.y -= baseScroll * detailSpeed

            if tree.position.y < -30 {
                // Reposition to top with new random x
                tree.position.y = scene.size.height + 30
                tree.position.x = CGFloat.random(in: 20...(scene.size.width - 20))
                let scale = CGFloat.random(in: 0.7...1.3)
                tree.setScale(scale)
            }
        }

        // Scroll clouds (slower, creates depth)
        for cloud in cloudNodes {
            cloud.position.y -= baseScroll * cloudSpeed

            if cloud.position.y < -80 {
                cloud.position.y = scene.size.height + 80
                cloud.position.x = CGFloat.random(in: -40...(scene.size.width + 40))
                cloud.alpha = CGFloat.random(in: 0.15...0.35)
                let scale = CGFloat.random(in: 0.6...1.5)
                cloud.setScale(scale)
            }
        }
    }
}
