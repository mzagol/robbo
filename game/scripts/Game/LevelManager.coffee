﻿window.app = window.app ? {}
app = window.app

class app.LevelManger 
	constructor: (@gameBoard,@game,@planetsList,@currentLevel) ->
		@lives = @game.startingNumberOfLives

	setupCanvas: () ->
		@canvas = $('<canvas></canvas>')
		@gameBoard.html('')
		@gameBoard.append(@canvas)
		@canvasContext2D = @canvas.get(0).getContext('2d')

	setupLevel: (planet) ->
		@setupCanvas()
		@eventAggregator = new app.EventAggregator()
		@drawingCtx = new app.DrawingContext @canvasContext2D
		@keyboardWatcher = new app.KeyboardWatcher @eventAggregator
		@timer = new app.TimeDelayedMethodCall
		@envCtx = new app.EnvironmentContext @eventAggregator,@drawingCtx,@timer
		@mapLoader = new app.MapLoader @envCtx,@canvas
		@effectManager = new app.MapEffects(@canvas,@envCtx)
		@setupWatchers()
		@subscribeToEvents()
		new app.ColorManager($('.game-board canvas'),planet.background,planet.transparent,planet.colors)

		@envCtx.eventAggregator.publish 'starting-number-of-bolts', planet.boltsToBeCollected
		@envCtx.eventAggregator.publish 'load-level',planet
		@watchCoordinates()
	setupWatchers: () ->
		@scrollWatcher = new app.ScrollWatcher @envCtx,@eventAggregator,@canvas
		@boltWatcher = new app.BoltWatcher @eventAggregator
		@keyWatcher = new app.KeyWatcher @eventAggregator
		@liveWatcher = new app.LiveWatcher @lives, @eventAggregator
		@ammoWatcher = new app.AmmoWatcher @eventAggregator
		@restartLevelWatcher = new app.RestartLevelWatcher @envCtx,@eventAggregator

	subscribeToEvents: () ->
		@envCtx.eventAggregator.subscribe 'robbo-destroyed',(()=>@onRobboDestroyed())
		@envCtx.eventAggregator.subscribe 'level-loaded',(()=>@onLevelStarts())
		@envCtx.eventAggregator.subscribe 'level-up',(()=>@onLevelUp())
		@eventAggregator.subscribe 'live-collected', (()=>@lives++)
		
	startGame: () -> 
		@setupLevel(@game.planets.single (p)=> p.index.toString() == @currentLevel.toString())

	onLevelUp: () ->
		@envCtx.eventAggregator.unsubscribeAll()
		@timer.resetToken()
		@currentLevel++
		planet = @game.planets.single (p)=> p.index.toString() == @currentLevel.toString()
		if (!planet?)
			$('.screen').hide()
			$('.game-finished-screen').show()
			return
		@setupLevel(planet)

	watchCoordinates: () ->
		@canvas.mousemove (e) =>
					x = Math.floor((e.pageX-@canvas.offset().left)/32.0)
					y = Math.floor((e.pageY-@canvas.offset().top)/32.0)
					if x<10 then x = '0'+x
					if y<10 then y = '0'+y
					$(app.Predef.Selectors.Coordinates).text "[#{x},#{y}]"

	onLevelStarts: () ->
		@envCtx.eventAggregator.publish 'level-started' 
		@planetsList.val(@currentLevel-1)
		@envCtx.sound 'level-starts'

	onRobboDestroyed: ()->
		@lives--
		explosionCallback = () =>
			@envCtx.sound 'explosion'
			for y in [0..@envCtx.height-1]
				for x in [0..@envCtx.width-1]
					obj = @envCtx.getObjAt x,y
					if obj? and @envCtx.getObjName(obj) isnt 'Smoke' and (obj.canBlowUp?() or obj.canBombBlowUp?())
						obj.isActive = false
						smoke = new app.Smoke @envCtx,obj.x,obj.y
						@envCtx.putObj smoke
						@envCtx.eventAggregator.unsubscribe obj
						@envCtx.unregisterRandomCalls obj
						smoke.init()
			setTimeout((()=>
				if @lives>0
					@envCtx.eventAggregator.publish('restart-level',@game.planets[@currentLevel-1])
				else
					$('.game-chrome').hide()
					$('.game-over-screen').show()
			),2000)
		setTimeout(explosionCallback,700)
