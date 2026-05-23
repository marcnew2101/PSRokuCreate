sub main()
	screen = createObject("roSGScreen")
	m.port = createObject("roMessagePort")
	screen.setMessagePort(m.port)

	scene = screen.createScene("AppScene")
	screen.show()

	while true
		msg = wait(0, m.port)
		msgType = type(msg)
		if msgType = "roSGScreenEvent" then
			if msg.isScreenClosed() then
				exit while
			end if
		end if
	end while
end sub