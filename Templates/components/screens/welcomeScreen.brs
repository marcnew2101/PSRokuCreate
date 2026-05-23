sub init()
	m.top.observeFieldScoped("visible", "onVisibleChanged")

	m.logo = m.top.findNode("logo")
	m.logo.poster.width = 200
	m.logo.poster.height = 200
	m.logo.poster.observeFieldScoped("loadStatus", "onSpinnerReady")

	m.layoutGroup = m.top.findNode("layoutGroup")
	m.welcomeText = m.top.findNode("welcomeText")

	setWelcomeText()
end sub

sub onSpinnerReady(nodeEvent as object)
	status = nodeEvent.getData()
	if status = "ready" then
		centerLayoutGroup()
		m.logo.control = "start"
	end if
end sub

sub onVisibleChanged(nodeEvent as object)
	visible = nodeEvent.getData()
	if visible then
		m.top.signalBeacon("AppLaunchComplete")
	end if
end sub

sub centerLayoutGroup()
	rect = m.layoutGroup.boundingRect()
	if rect.width = 0 or rect.height = 0 then return

	res = m.top.getScene().currentDesignResolution
	deltaX = (res.width / 2) - (rect.x + rect.width / 2)
	deltaY = (res.height / 2) - (rect.y + rect.height / 2)
	if abs(deltaX) < 1 and abs(deltaY) < 1 then return

	current = m.layoutGroup.translation
	m.layoutGroup.translation = [current[0] + deltaX, current[1] + deltaY]
end sub

sub setWelcomeText()
	appInfo = createObject("roAppInfo")
	m.welcomeText.text = "Welcome to " + appInfo.GetTitle() + "!"
end sub
