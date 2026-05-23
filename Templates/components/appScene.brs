sub init()
	m.top.backgroundURI = "pkg:/images/gradients/background.png"
	addScreen("WelcomeScreen")
end sub

sub addScreen(screenName as string, showScreen = true as boolean)
	screen = createObject("roSGNode", screenName)
	screen.visible = showScreen
	m.top.appendChild(screen)
end sub