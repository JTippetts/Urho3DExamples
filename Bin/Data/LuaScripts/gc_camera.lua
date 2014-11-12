-- Goblinson Crusoe
-- Combat Camera

GameCamera=ScriptObject()

function GameCamera:Start()
	self:SubscribeToEvent("CameraLock", "GameCamera:Lock")
	self:SubscribeToEvent("CameraUnlock", "GameCamera:Unlock")
	self:SubscribeToEvent("Update", "GameCamera:HandleUpdate")
	self:SubscribeToEvent("CameraSetPosition", "GameCamera:SetPosition")
	self:SubscribeToEvent("CameraResetPosition", "GameCamera:ResetPosition")
	self:SubscribeToEvent("CameraSetAngle", "GameCamera:SetCamAngle")
	self:SubscribeToEvent("CameraResetAngle", "GameCamera:ResetCamAngle")
	self:SubscribeToEvent("CameraGetMouseGround", "GameCamera:GetMouseGroundLocation")
	self:SubscribeToEvent("CameraShake", "GameCamera:HandleShakeCamera")
	self:SubscribeToEvent("RequestCameraRotation", "GameCamera:HandleRequestCameraRotation")
	
	self.cellsize=128           -- Orthographic on-screen size of 1 unit 
	self.camangle=30            -- 30 degrees for standard 2:1 tile ratio
	self.rotangle=45            -- 45 degrees for standard axonometric projections
	self.follow=10              -- Target zoom distance
	self.minfollow=1            -- Closest zoom distance for perspective modes
	self.maxfollow=20           -- Furthest zoom distance for perspective modes
	self.clipdist=60            -- Far clip distance
	self.verticaloffset=0.25    -- Offset to look at avatar's head instead of feet
	self.clipcamera=true        -- Cause camera to clip when view is obstructed by world geometry
	
	self.allowspin=true         -- Camera yaw angle can be adjusted via MOUSEB_RIGHT + Mouse move in X
	self.allowpitch=true        -- Camera pitch can be adjusted via MOUSEB_RIGHT + Mouse move in y
	self.allowzoom=true         -- Camera can be zoomed via Mouse wheel
	self.orthographic=false     -- Orthographic projection
	
	self.curfollow=self.follow  -- Current zoom distance (internal use only)
	self.followvel=0            -- Zoom movement velocity (internal use only)
	self.newpos=Vector3(0,self.verticaloffset,0)
	self.posvelocity=Vector3(0,0,0)
	self.pos=Vector3(0,self.verticaloffset,0)
	
	self.facinglock=false
	self.minimap=self.node:GetScene():GetScriptObject("MinimapContainer")
end

function GameCamera:Finalize()
	self.curfollow=self.follow
	self.pos.y=self.verticaloffset
	self.newpos.y=self.verticaloffset
	
	-- Set up node hierarchy
	-- root level node is used for position and yaw control
	-- shakenode is used for applying camera shake translations
	-- anglenode is used for pitch control
	-- cameranode holds the camera and is used for zoom distance control as well
	
	self.shakenode=self.node:CreateChild("ShakeNode", LOCAL)
	self.anglenode=self.shakenode:CreateChild("AngleNode", LOCAL)
	self.cameranode=self.anglenode:CreateChild("CameraNode", LOCAL)
	self.camera=self.cameranode:CreateComponent("Camera")
	
	-- If orthographic, use the cellsize to calculate the orthographic size
	
	if self.orthographic then
		self.camera:SetOrthographic(true)
		local w,h=graphics:GetWidth(), graphics:GetHeight()
		self.camera:SetOrthoSize(Vector2(w/(self.cellsize*math.sqrt(2)), h/(self.cellsize*math.sqrt(2))))
	end
	
	self.viewport=Viewport:new(self.node:GetScene(), self.camera)
    renderer:SetViewport(0, self.viewport)
	
	-- Apply initial pitch/yaw/zoom
	
	self.node:SetRotation(Quaternion(self.rotangle, Vector3(0,1,0)))
	self.cameranode:SetPosition(Vector3(0,0,-self.follow))
	self.anglenode:SetRotation(Quaternion(self.camangle, Vector3(1,0,0)))
	self.node:SetPosition(self.pos)
	
	self.shakemagnitude=0
	self.shakespeed=0
	self.shaketime=0
	self.shakedamping=0
	
	self.camera:SetFarClip(self.clipdist)
end

function GameCamera:SetCamera(dt)
	-- Calculate camera shake factors
	self.shaketime=self.shaketime+dt*self.shakespeed
	local s=math.sin(self.shaketime)*self.shakemagnitude
	local shakepos=Vector3(math.sin(self.shaketime*3)*s, math.cos(self.shaketime)*s,0)
	self.shakemagnitude=self.shakemagnitude-self.shakedamping*dt
	if self.shakemagnitude<0 then self.shakemagnitude=0 end
	
	-- Set camera shake factor (do it here rather than before the camera clipping, so that
	-- shake translations do not affect the casting of the view ray, which could cause
	-- the camera zoom to go haywire
	self.shakenode:SetPosition(shakepos)
	
	-- Set camera pitch, zoom and yaw.
	self.node:SetRotation(Quaternion(self.rotangle, Vector3(0,1,0)))
	self.cameranode:SetPosition(Vector3(0,0,-self.curfollow))
	self.anglenode:SetRotation(Quaternion(self.camangle, Vector3(1,0,0)))
end

function GameCamera:HandleUpdate(eventType, eventData)
	local dt=eventData:GetFloat("TimeStep")
	
	if self.allowzoom and not ui:GetElementAt(ui.cursor:GetPosition()) then
		-- Modify follow (zoom) in response to wheel motion
		-- This modifies the target zoom, or the desired zoom level, not the actual zoom.
		
		local wheel=input:GetMouseMoveWheel()
		self.follow=self.follow-wheel*dt*20
		if self.follow<self.minfollow then self.follow=self.minfollow end
		if self.follow>self.maxfollow then self.follow=self.maxfollow end
	end
	
	if input:GetMouseButtonDown(MOUSEB_RIGHT) and (self.allowspin or self.allowpitch) then
		-- Hide the cursor when altering the camera angles
		ui.cursor.visible=false
		
		if self.allowpitch then
			-- Adjust camera pitch angle
			
			local mmovey=input:GetMouseMoveY()/graphics:GetHeight()
			self.camangle=self.camangle+mmovey*600

			if self.camangle<1 then self.camangle=1 end
			if self.camangle>89 then self.camangle=89 end
		end
		
		if self.allowspin then
			-- Adjust camera yaw angle
			
			local mmovex=input:GetMouseMoveX()/graphics:GetWidth()
			self.rotangle=self.rotangle+mmovex*800
			while self.rotangle<0 do self.rotangle=self.rotangle+360 end
			while self.rotangle>=360 do self.rotangle=self.rotangle-360 end
		end
		
	else
		ui.cursor.visible=true
	end
	
	self:SpringFollow(dt)
	self:SpringPosition(dt)
	self:SetCamera(dt)
end

function GameCamera:GetMouseRay()
	--local mousepos=input:GetMousePosition()
	local mousepos=ui.cursor:GetPosition()
	return self.camera:GetScreenRay(mousepos.x/graphics:GetWidth(), mousepos.y/graphics:GetHeight())
end

function  GameCamera:GetMouseGroundLocation(eventType, eventData)
	local ray=self:GetMouseRay()
	local p=self.node:GetPosition()
	local x,y,z=p.x,p.y,p.z
	local hitdist=ray:HitDistance(Plane(Vector3(0,1,0), Vector3(0,0,0)))
	local dx=(ray.origin.x+ray.direction.x*hitdist)
	local dz=(ray.origin.z+ray.direction.z*hitdist)
	--return dx,dz
	eventData:SetVector2("location", Vector2(dx,dz))
end

function  GameCamera:SpringPosition(dt)
	local dx=self.newpos.x - self.pos.x
	local dy=self.newpos.y - self.pos.y
	local dz=self.newpos.z - self.pos.z
	
	local ax=8*dx-6*self.posvelocity.x
	local ay=8*dy-6*self.posvelocity.y
	local az=8*dz-6*self.posvelocity.z
	
	self.posvelocity.x=self.posvelocity.x+dt*ax
	self.posvelocity.y=self.posvelocity.y+dt*ay
	self.posvelocity.z=self.posvelocity.z+dt*az
	
	self.pos.x=self.pos.x+dt*self.posvelocity.x
	self.pos.y=self.pos.y+dt*self.posvelocity.y
	self.pos.z=self.pos.z+dt*self.posvelocity.z
end

function  GameCamera:SpringCamAngle(dt)
	
	local da=self.newcamangle-self.camangle
	local accel=6*da-5*self.camanglevelocity
	self.camanglevelocity=self.camanglevelocity+dt*accel
	self.camangle=self.camangle+dt*self.camanglevelocity
	
	while self.camangle<0 do self.camangle=self.camangle+360 end
	while self.camangle>=360 do self.camangle=self.camangle-360 end
end

CombatCameraComponent=ScriptObject()

function CombatCameraComponent:Start()
	self:SubscribeToEvent("CameraLock", "CombatCameraComponent:Lock")
	self:SubscribeToEvent("CameraUnlock", "CombatCameraComponent:Unlock")
	self:SubscribeToEvent("Update", "CombatCameraComponent:HandleUpdate")
	self:SubscribeToEvent("CameraSetPosition", "CombatCameraComponent:SetPosition")
	self:SubscribeToEvent("CameraResetPosition", "CombatCameraComponent:ResetPosition")
	self:SubscribeToEvent("CameraSetAngle", "CombatCameraComponent:SetCamAngle")
	self:SubscribeToEvent("CameraResetAngle", "CombatCameraComponent:ResetCamAngle")
	self:SubscribeToEvent("CameraGetMouseGround", "CombatCameraComponent:GetMouseGroundLocation")
	
	self.minfollow=0
	self.maxfollow=20
	self.minvertangle=0
	self.maxvertangle=89
	self.offset=0
	self.camangle=0
	self.follow=10
	self.vertangle=30
	
	self.pos={x=0,y=self.offset,z=0}
	self.newpos={x=0,y=self.offset,z=0}
	self.posvelocity={x=0, y=0, z=0}
	
	self.newcamangle=self.camangle
	self.camanglevelocity=0
	
	self.facinglock=false
	
	self.minimap=self.node:GetScene():GetScriptObject("MinimapContainer")
end

function CombatCameraComponent:Construct(minfollow, maxfollow, follow, minangle, maxangle, angle, camangle, verticaloffset)
	self.minfollow=minfollow
	self.maxfollow=maxfollow
	self.minvertangle=minangle
	self.maxvertangle=maxangle
	self.follow=math.max(minfollow, math.min(maxfollow, follow))
	self.vertangle=math.max(minangle, math.min(maxangle, angle))
	self.camangle=camangle
	self.offset=verticaloffset
	
	self.pos={x=0,y=self.offset,z=0}
	self.newpos={x=0,y=self.offset,z=0}
	self.posvelocity={x=0, y=0, z=0}
	
	self.newcamangle=self.camangle
	self.camanglevelocity=0
	
	local scene=self.node:GetScene()
	
	self.cameranode=self.node:CreateChild("CamNode")
	self.camera=self.cameranode:CreateComponent("Camera")
	local viewport = Viewport(scene, self.camera)
    renderer:SetViewport(0, viewport)
	
	self.facinglock=false
end

function CombatCameraComponent:Finalize()
	if self.cameranode then
		self.camera=nil
		self.cameranode:Remove()
		self.cameranode=nil
	end
	
	self.cameranode=self.node:CreateChild("CamNode")
	self.camera=self.cameranode:CreateComponent("Camera")
	self.camera:SetFarClip(60)
	local viewport = Viewport:new(self.node:GetScene(), self.camera)
    renderer:SetViewport(0, viewport)
	
	self.facinglock=true
	
end

function CombatCameraComponent:SetCamera()
	self.node:SetPosition(Vector3(self.pos.x, self.pos.y, self.pos.z))
	self.node:SetRotation(Quaternion(self.camangle+90, Vector3(0,-1,0)))
	self.cameranode:SetPosition(Vector3(0, self.follow*math.sin(self.vertangle*math.pi/180), -self.follow*math.cos(self.vertangle*math.pi/180)))
	self.cameranode:LookAt(Vector3(self.pos.x, self.pos.y, self.pos.z), Vector3(0,1,0))
	
	self.minimap.cameranode:SetPosition(Vector3(self.pos.x, self.minimap.y, self.pos.z))
	
	local crad=((self.camangle+180)*math.pi)/180
	self.minimap.cameranode:LookAt(Vector3(self.pos.x, self.minimap.y-10, self.pos.z), Vector3(math.cos(crad),0,math.sin(crad)))
	--self.minimap.cameranode:SetRotation(Quaternion(self.camangle+90, Vector3(-1,0,0)))
	--self.minimap.cameranode:SetRotation(Vector3(0,0,self.camangle))
end

function CombatCameraComponent:GetMouseRay()
	--local mousepos=input:GetMousePosition()
	local mousepos=ui.cursor:GetPosition()
	return self.camera:GetScreenRay(mousepos.x/graphics:GetWidth(), mousepos.y/graphics:GetHeight())
end

function CombatCameraComponent:GetMouseGroundLocation(eventType, eventData)
	local ray=self:GetMouseRay()
	local p=self.node:GetPosition()
	local x,y,z=p.x,p.y,p.z
	local hitdist=ray:HitDistance(Plane(Vector3(0,1,0), Vector3(0,0,0)))
	local dx=(ray.origin.x+ray.direction.x*hitdist)
	local dz=(ray.origin.z+ray.direction.z*hitdist)
	--return dx,dz
	eventData:SetVector2("location", Vector2(dx,dz))
end

function CombatCameraComponent:SpringPosition(dt)
	local dx=self.newpos.x - self.pos.x
	local dy=self.newpos.y - self.pos.y
	local dz=self.newpos.z - self.pos.z
	
	local ax=8*dx-6*self.posvelocity.x
	local ay=8*dy-6*self.posvelocity.y
	local az=8*dz-6*self.posvelocity.z
	
	self.posvelocity.x=self.posvelocity.x+dt*ax
	self.posvelocity.y=self.posvelocity.y+dt*ay
	self.posvelocity.z=self.posvelocity.z+dt*az
	
	self.pos.x=self.pos.x+dt*self.posvelocity.x
	self.pos.y=self.pos.y+dt*self.posvelocity.y
	self.pos.z=self.pos.z+dt*self.posvelocity.z
end

function CombatCameraComponent:SpringCamAngle(dt)
	
	local da=self.newcamangle-self.camangle
	local accel=6*da-5*self.camanglevelocity
	self.camanglevelocity=self.camanglevelocity+dt*accel
	self.camangle=self.camangle+dt*self.camanglevelocity
	
	while self.camangle<0 do self.camangle=self.camangle+360 end
	while self.camangle>=360 do self.camangle=self.camangle-360 end
end

function CombatCameraComponent:Lock(eventType, eventData)
	self.facinglock=true
end

function CombatCameraComponent:Unlock(eventType, eventData)
	self.facinglock=false
end

function CombatCameraComponent:HandleUpdate(eventType, eventData)
	local dt=eventData:GetFloat("TimeStep")
	
	self.facinglock=false
	
	if input:GetMouseButtonDown(MOUSEB_MIDDLE) then
		--input:SetMouseVisible(false)
		ui.cursor.visible=false
		
		if self.facinglock==false then
			local mmove=input:GetMouseMoveX()/graphics:GetWidth()
			self.camangle=self.camangle-mmove*800
			--print(self.camangle.."\n")
			while self.camangle>=360 do self.camangle=self.camangle-360 end
			while self.camangle<0 do self.camangle=self.camangle+360 end
		end
		
		local mmove=input:GetMouseMoveY()/graphics:GetHeight()
		self.vertangle=self.vertangle+mmove*600

		if self.vertangle<self.minvertangle then self.vertangle=self.minvertangle end
		if self.vertangle>self.maxvertangle then self.vertangle=self.maxvertangle end
		
	else
		--input:SetMouseVisible(true)
		ui.cursor.visible=true
		
	end
	
	--if not ui:GetElementAt(input:GetMousePosition()) then
	if not ui:GetElementAt(ui.cursor:GetPosition()) then
		local wheel=input:GetMouseMoveWheel()
		--print(wheel)
	
		self.follow=self.follow-wheel*dt*20
		if self.follow<self.minfollow then self.follow=self.minfollow end
		if self.follow>self.maxfollow then self.follow=self.maxfollow end
	end
	
	--print(self.follow.."\n")
	
	self:SpringPosition(dt)
	if self.facinglock then self:SpringCamAngle(dt) end
	self:SetCamera()
end

function CombatCameraComponent:ResetPosition(eventType, eventData)
	self.pos.x=eventData:GetFloat("x")
	self.pos.y=eventData:GetFloat("y")
	self.pos.z=eventData:GetFloat("z")
	
	self.newpos.x=self.pos.x
	self.newpos.y=self.pos.y
	self.newpos.z=self.pos.z
end

function CombatCameraComponent:ResetCamAngle(eventType, eventData)
	self.camangle=eventData:GetFloat("angle")
	self.newcamangle=self.camangle
end

function CombatCameraComponent:SetPosition(eventType, eventData)
	self.newpos.x=eventData:GetFloat("x")
	self.newpos.y=eventData:GetFloat("y")
	self.newpos.z=eventData:GetFloat("z")
end

function CombatCameraComponent:SetCamAngle(eventType, eventData)
	local newangle=eventData:GetFloat("angle")
	
	local d1=math.abs(self.camangle-newangle)
	local d2=math.abs(self.camangle-(newangle+360))
	local d3=math.abs(self.camangle-(newangle-360))
	
	local m=math.min(d1,d2,d3)
	if m==d1 then self.newcamangle=newangle
	elseif m==d2 then self.newcamangle=newangle+360
	else self.newcamangle=newangle-360
	end
	
	--print("New cam angle: "..self.newcamangle.."\n")
end



-- Camera controller

-- Add to any object that should control the camera
CombatCameraController=ScriptObject()

function CombatCameraController:Start()
	self.active=false
	
	self:SubscribeToEvent(self.node, "CombatActivate", "CombatCameraController:CombatTurnBegin")
	self:SubscribeToEvent(self.node, "CombatDeactivate", "CombatCameraController:CombatTurnEnd")
	self:SubscribeToEvent(self.node, "CombatSetBusy", "CombatCameraController:CombatSetBusy")
	self:SubscribeToEvent(self.node, "CombatSetWait", "CombatCameraController:CombatSetWait")
	self:SubscribeToEvent(self.node, "CombatSetIdle", "CombatCameraController:CombatSetWait")
	self:SubscribeToEvent("Update", "CombatCameraController:HandleUpdate")
	self.offset=1
	self.vm=VariantMap()
end

function CombatCameraController:TransformChanged()
	if self.active==false then return end
	
	local p=self.node:GetPosition()
	local x,y,z=p.x,p.y,p.z
	p=self.node:GetDirection()
	local fx,fy,fz=p.x,p.y,p.z
	
	local angle=math.atan2(fz,fx)*180/math.pi
	--print("Changed angle: "..angle.."\n")
	
	--local vm=VariantMap()
	self.vm:SetFloat("x", x)
	self.vm:SetFloat("y", y+self.offset)
	self.vm:SetFloat("z", z)
	
	self.vm:SetFloat("angle", angle)
	
	
	self.node:SendEvent("CameraSetPosition", self.vm)
	self.node:SendEvent("CameraSetAngle", self.vm)
end

function CombatCameraController:HandleUpdate(eventType, eventData)
	--if input:GetMouseButtonDown(MOUSEB_RIGHT) then
		--SendEvent("CameraLock", emptyvm)
	--else
		--SendEvent("CameraUnlock", emptyvm)
	--end
end

function CombatCameraController:CombatTurnBegin(eventType, eventData)
	self.active=true
	
end

function CombatCameraController:CombatTurnEnd(eventType, eventData)
	self.active=false
	self.node:SendEvent("CameraUnlock", eventData)
end

function CombatCameraController:CombatSetBusy(eventType, eventData)
	if self.active==false then return end
	self.node:SendEvent("CameraLock", eventData)
end

function CombatCameraController:CombatSetWait(eventType, eventData)
	if self.active==false then return end
	self.node:SendEvent("CameraUnlock", eventData)
end