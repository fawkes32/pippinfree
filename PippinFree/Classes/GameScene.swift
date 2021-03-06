//
//  GameScene.swift
//  PippinFree
//
//  Created by Jeremy Novak on 8/14/14.
//  Copyright (c) 2014 Jeremy Novak. All rights reserved.
//

import SpriteKit
import GameKit

class GameScene: SKScene, SKPhysicsContactDelegate, GKGameCenterControllerDelegate {
    
    private let viewSize = UIScreen.mainScreen().bounds.size
    
    private var state = GameState.Tutorial
    private let worldNode = SKNode()
    private let hills = Hills()
    private let ground = Ground()
    private let player = Player()
    private let scoreFont = BMGlyphFont(name: "ScoreFont")
    private var score:Int = 0
    private var retry = SKSpriteNode()
    private var leaders = SKSpriteNode()
    private var rate = SKSpriteNode()
    private var scoreHud = BMGlyphLabel()
    private let musicButton = MusicButton()
    private let tutorial = Tutorial()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    override func didMoveToView(view: SKView) {
        #if FREE
            NSNotificationCenter.defaultCenter().postNotificationName("AdBannerHide", object: nil)
        #endif

        
        state = GameState.Tutorial
        
        self.scene?.userInteractionEnabled = false
        self.setupWorld()
        self.switchToTutorial()
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        let touch:UITouch = touches.anyObject() as UITouch
        let touchLocation = touch.locationInNode(self)
        
        switch state {
            case GameState.Tutorial:
                
                if touchLocation.y < viewSize.height * 0.75 {
                    self.switchToPlay()
                }
            
                if musicButton.containsPoint(touchLocation) {
                    musicButton.toggleMusic()
                }
            
            case GameState.Play:
                player.fly()
            
                if musicButton.containsPoint(touchLocation) {
                    musicButton.toggleMusic()
                }

        
            case GameState.GameOver:
                if retry.containsPoint(touchLocation) {
                    self.switchToNewGame()
                }
                
                if leaders.containsPoint(touchLocation) {
                    self.showLeaderBoard()
                }
                
            
                if musicButton.containsPoint(touchLocation) {
                    musicButton.toggleMusic()
                }

            
            default:
                return
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        switch state {
            case GameState.Tutorial:
                return
            
            case GameState.Play:
                player.update()
                return
            
            case GameState.GameOver:
                return
            
            default:
                return
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact!) {
        if state == GameState.Tutorial || state == GameState.GameOver {
            return
        } else {
            var other:SKPhysicsBody = contact.bodyA.categoryBitMask == Contact.Player ? contact.bodyB : contact.bodyA
            
            if other.categoryBitMask == Contact.Scene {
                self.runAction(GameSoundsSharedInstance.bounce)
                self.runAction(GameSoundsSharedInstance.falling)
                self.switchToGameOver()
                
            } else if other.categoryBitMask == Contact.Logs {
                self.runAction(GameSoundsSharedInstance.whack)
                self.runAction(GameSoundsSharedInstance.falling)
                self.switchToGameOver()
                
            } else if other.categoryBitMask == Contact.Score {
                self.updateScore()
            }
        }
    }
    
    // MARK: Setup
    func setupWorld() {
        // Gravity set in switchToPlay()
        self.physicsWorld.gravity = CGVectorMake(0, 0)
        self.physicsWorld.contactDelegate = self
        
        // Add the gameNode to the scene
        self.addChild(worldNode)
        
        // Background color
        self.backgroundColor = SKColorFromRBG(kBGColor)
        
        // Sun
        let sun = SKSpriteNode(texture: GameTexturesSharedInstance.textureAtlas.textureNamed("Sun"))
        sun.position = CGPoint(x: viewSize.width * 0.15, y: viewSize.height * 0.8)
        sun.zPosition = GameLayer.Sky
        worldNode.addChild(sun)
        
        // Clouds
        let clouds = Clouds()
        worldNode.addChild(clouds)
        
        // Hills
        worldNode.addChild(hills)
        
        // Ground
        worldNode.addChild(ground)
        
        // Player
        worldNode.addChild(player)
        
        // Bounding box of playable area
        self.physicsBody = SKPhysicsBody(edgeLoopFromRect: CGRectMake(0, ground.size.height, viewSize.width, (viewSize.height - ground.size.height)))
        self.physicsBody?.categoryBitMask = Contact.Scene
        
        // Score
        score = 0
        scoreHud = BMGlyphLabel(text: NSString(format: "%d", score), font: scoreFont)
        scoreHud.position = CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.85)
        scoreHud.zPosition = GameLayer.Interface
        scoreHud.hidden = true
        worldNode.addChild(scoreHud)
        
        // Music Button
        self.addChild(musicButton)
    }
    
    // MARK: State Methods
    func switchToTutorial() {
        state = GameState.Tutorial
        
        self.addChild(tutorial)
        tutorial.blinkTutorial()
    }
    
    func switchToPlay() {
        state = GameState.Play
        tutorial.hideTutorial()
        
        // Set gravity
        if IS_IPAD {
            self.physicsWorld.gravity = CGVectorMake(0, -10)
        } else {
            self.physicsWorld.gravity = CGVectorMake(0, -5.0)
        }
        
        // Scroll world and animate player
        ground.scrollGround()
        hills.scrollHills()
        player.animate()
        
        // Unhide Score HUD
        scoreHud.hidden = false
        
        // Spawn Logs
        let delay = SKAction.waitForDuration(1.0)
        let spawn = SKAction.runBlock({
            let logs = Logs()
            self.worldNode.addChild(logs)
        })
        let spawnSequence = SKAction.sequence([delay, spawn])
        worldNode.runAction(SKAction.repeatActionForever(spawnSequence), withKey: kNameSpawn)
    }
    
    func switchToGameOver() {
        state = GameState.GameOver
        
        #if FREE
            NSNotificationCenter.defaultCenter().postNotificationName("AdBannerShow", object: nil)
        #endif
        
        // Stop scrolling and flash/shake background
        self.flashBackground()
        ground.stopGround()
        hills.stopHills()
        
        // Hide the Score HUD
        scoreHud.hidden = true
        
        // Stop the Logs
        worldNode.removeActionForKey(kNameSpawn)
        worldNode.enumerateChildNodesWithName(kNameLogs, usingBlock: { node, stop in
            node.removeAllActions()
        })
        
        // Animate smoke on player
        let smoke = Smoke()
        worldNode.addChild(smoke)
        smoke.animateSmoke(player.position)
        
        // Blink and hide player
        player.blink()
        
        // Game Over
        let gameOver = GameOver(score: score)
        worldNode.addChild(gameOver)
        
        // Retry Button
        retry = SKSpriteNode(texture: GameTexturesSharedInstance.textureAtlas.textureNamed("Retry"))
        retry.position = CGPoint(x: viewSize.width * 0.25, y: viewSize.height * 0.3)
        retry.zPosition = GameLayer.Interface
        worldNode.addChild(retry)
        
        // Leaders Button
        leaders = SKSpriteNode(texture: GameTexturesSharedInstance.textureAtlas.textureNamed("Leaders"))
        leaders.position = CGPoint(x: viewSize.width * 0.75, y: viewSize.height * 0.3)
        leaders.zPosition = GameLayer.Interface
        worldNode.addChild(leaders)
    }
    
    func switchToNewGame() {
        let gameScene = GameScene(size: viewSize)
        gameScene.scaleMode = SKSceneScaleMode.AspectFill
        let gameTransition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.25)
        self.view?.presentScene(gameScene, transition: gameTransition)
    }
    
    func flashBackground() {
        let shake = SKAction.screenShakeWithNode(worldNode, amount: CGPoint(x: 20, y: 15), oscillations: 10, duration: 0.75)
        let colorBackground = SKAction.runBlock({
            self.backgroundColor = SKColor.redColor()
            self.runAction(SKAction.waitForDuration(0.5), completion: {
                self.backgroundColor = SKColorFromRBG(kBGColor)
            })
        })
        let flashGroup = SKAction.group([shake, colorBackground])
        self.runAction(flashGroup)
    }
    
    // MARK: Score
    func updateScore() {
        score++
        scoreHud.text = NSString(format: "%d", score)
        worldNode.runAction(GameSoundsSharedInstance.coin)
        
        if score % 5 == 0 {
            worldNode.runAction(GameSoundsSharedInstance.oink)
        }
    }
    
    func showLeaderBoard() {
        if !NetworkCheck.checkConnection() {
            let alert = UIAlertView()
            alert.title = "No Network Access"
            alert.message = "Game Center is not available."
            alert.addButtonWithTitle("Ok")
            alert.show()
        } else {
            let gameCenterController = GKGameCenterViewController()
            gameCenterController.gameCenterDelegate = self
            gameCenterController.viewState = GKGameCenterViewControllerState.Leaderboards
            let viewController = self.view?.window?.rootViewController
            viewController?.presentViewController(gameCenterController, animated: true, completion: nil)
        }
    }
    
    func gameCenterViewControllerDidFinish(gameCenterViewController: GKGameCenterViewController!) {
        gameCenterViewController.dismissViewControllerAnimated(true, completion: nil)
    }
}
