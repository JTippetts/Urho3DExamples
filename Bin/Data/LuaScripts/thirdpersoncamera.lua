--[[Third person camera
Implement a third person camera.

System operates in two parts.

The first part is a script object that implements the actual camera, intended to be instanced on a dedicated node.
The sceond part is a script object to be instanced on any object intended to control the camera, such as the player avater.

The camera is customizable. Many parameters are provided to modify its behavior. The camera component creates a node chain
that implements a third person view from a specified angle (pitch and yaw). The camera follows at a specified distance, with
an optional ability to zoom, as well as an optional ability to modify the pitch and/or yaw by holding down the middle mouse
button and moving the mouse vertically for pitch and horizontally for yaw.

The camera can be set to either perspective or orthographic. If orthographic, the member cellsize indicates
how large 1 game unit appears on-screen. Note that zoom is implemented by a Z translation of the camera node, so zoom is
not implemented for orthographic projection.

The camera tracks the location of the active camera controller. It can track tightly (locked on) or it can track using
a spring equation to soften movement. This is controlled through the springtrack member.



]]
require 'picking'

ThirdPersonCamera=ScriptObject()

function ThirdPersonCamera:Start()
	-- Override any of these parameters when instancing the component in order to change the characteristics
	-- of the view.
	
	self.cellsize=128           -- Orthographic on-screen size of 1 unit 
	self.camangle=30            -- 30 degrees for standard 2:1 tile ratio
	self.rotangle=45            -- 45 degrees for standard axonometric projections
	self.follow=10              -- Target zoom distance
	self.minfollow=1            -- Closest zoom distance for perspective modes
	self.maxfollow=20           -- Furthest zoom distance for perspective modes
	self.clipdist=60            -- Far clip distance
	self.clipcamera=true        -- Cause camera to clip when view is obstructed by world geometry
	self.springtrack=true       -- Use a spring function for location tracking to smooth camera translation
								-- Set to false to lock camera tightly to target.
	self.allowspin=true         -- Camera yaw angle can be adjusted via MOUSEB_MIDDLE + Mouse move in X
	self.allowpitch=true        -- Camera pitch can be adjusted via MOUSEB_MIDDLE + Mouse move in y
	self.allowzoom=true         -- Camera can be zoomed via Mouse wheel
	self.orthographic=false     -- Orthographic projection
	
	self.curfollow=self.follow  -- Current zoom distance (internal use only)
	self.followvel=0            -- Zoom movement velocity (internal use only)
	self.pos=Vector3(0,0,0)         -- Vars used for location spring tracking (internal use only)
	self.newpos=Vector3(0,0,0)
	self.posvelocity=Vector3(0,0,0)
end

function ThirdPersonCamera:Stop()
    print("Stopping")
end

function ThirdPersonCamera:Finalize()
	self.curfollow=self.follow
    print("Hello")
	
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
		self.camera:SetOrthoSize(Vector2(w/(self.cellsize), h/(self.cellsize)))
	end
	
	self.viewport=Viewport:new(self.node:GetScene(), self.camera)
    renderer:SetViewport(0, self.viewport)
	
	-- Apply initial pitch/yaw/zoom
	
	self.node:SetRotation(Quaternion(self.rotangle, Vector3(0,1,0)))
	self.cameranode:SetPosition(Vector3(0,0,-self.follow))
	self.anglenode:SetRotation(Quaternion(self.camangle, Vector3(1,0,0)))
	self.node:SetPosition(Vector3(0,0,0))
	
	--self:SubscribeToEvent("Update", "ThirdPersonCamera:HandleUpdate")
	self:SubscribeToEvent("ShakeCamera", "ThirdPersonCamera:HandleShakeCamera")
	self:SubscribeToEvent("CameraGetMouseGround", "ThirdPersonCamera:HandleRequestMouseGround")
	self:SubscribeToEvent("RequestMouseRay", "ThirdPersonCamera:HandleRequestMouseRay")
	self:SubscribeToEvent("CameraSetPosition", "ThirdPersonCamera:HandleSetCameraPosition")
	self:SubscribeToEvent("CameraResetPosition", "ThirdPersonCamera:HandleResetCameraPosition")
	self:SubscribeToEvent("RequestCameraRotation", "ThirdPersonCamera:HandleRequestCameraRotation")
	
	self.shakemagnitude=0
	self.shakespeed=0
	self.shaketime=0
	self.shakedamping=0
	
	self.camera:SetFarClip(self.clipdist)
end

function ThirdPersonCamera:GetMouseRay()
	-- Construct a ray based on current mouse coordinates.
	
	local mousepos
	if input.mouseVisible then
		mousepos=input:GetMousePosition()
	else
		mousepos=ui:GetCursorPosition()
	end
	
	return self.camera:GetScreenRay(mousepos.x/graphics.width, mousepos.y/graphics.height)
end

function ThirdPersonCamera:GetMouseGround()
	-- Calculate the intersection of the current mouse coordinates with the ground plane
	
	local ray=self:GetMouseRay()
	
	--local x,y,z=self.node:GetWorldPositionXYZ()
	local hitdist=ray:HitDistance(Plane(Vector3(0,1,0), Vector3(0,0,0)))
	local dx=(ray.origin.x+ray.direction.x*hitdist)
	local dz=(ray.origin.z+ray.direction.z*hitdist)
	return dx,dz
end

function ThirdPersonCamera:CameraPick(ray, followdist)
	-- Cast a ray from camera target toward camera and determine the nearest clip position.
	-- Only objects marked by setting node user var solid=true are considered.
	
	local scene=self.node:GetScene()
	local octree = scene:GetComponent("Octree")
    
	local resultvec=octree:Raycast(ray, RAY_TRIANGLE, followdist, DRAWABLE_GEOMETRY)
	if #resultvec==0 then return followdist end
	
	local i
	for i=1,#resultvec,1 do
		local node=TopLevelNodeFromDrawable(resultvec[i].drawable, scene)
		if node:GetVars():GetBool("solid")==true and resultvec[i].distance>=0 then
			return math.min(resultvec[i].distance-0.05,followdist)
		end
	end
	
	return followdist
end

function ThirdPersonCamera:HandleSetCameraPosition(eventType, eventData)
	-- Camera position setting. Responds to event generated by CameraControl components.
	self.newpos.x=eventData:GetFloat("x")
	self.newpos.y=eventData:GetFloat("y")
	self.newpos.z=eventData:GetFloat("z")
end

function ThirdPersonCamera:HandleResetCameraPosition(eventType, eventData)
	-- Camera position setting. Responds to event generated by CameraControl components.
	self.pos.x=eventData:GetFloat("x")
	self.pos.y=eventData:GetFloat("y")
	self.pos.z=eventData:GetFloat("z")
	
	self.newpos.x=self.pos.x
	self.newpos.y=self.pos.y
	self.newpos.z=self.pos.z
end

function ThirdPersonCamera:HandleRequestCameraRotation(eventType, eventData)
	-- Request to provide the camera pitch and yaw, for controllers that use it such as the WASD controllers
	
	eventData:SetFloat("spin", self.rotangle)
	eventData:SetFloat("pitch", self.camangle)
end

function ThirdPersonCamera:SpringFollow(dt)
	-- Spring function to smooth camera zoom action
	
	local df=self.follow-self.curfollow
	local af=9*df-6*self.followvel
	self.followvel=self.followvel+dt*af
	self.curfollow=self.curfollow+dt*self.followvel
end

function ThirdPersonCamera:SpringPosition(dt)
	local d=self.newpos-self.pos
	local a=d*Vector3(8,8,8) - self.posvelocity*Vector3(6,6,6)
	self.posvelocity=self.posvelocity+a*Vector3(dt,dt,dt)
	self.pos=self.pos+self.posvelocity*Vector3(dt,dt,dt)
end

function ThirdPersonCamera:Update(dt)
    --if not self.node then return end
	--local dt=eventData:GetFloat("TimeStep")
	
	-- Calculate camera shake factors
	self.shaketime=self.shaketime+dt*self.shakespeed
	local s=math.sin(self.shaketime)*self.shakemagnitude
	
	local shakepos=Vector3(math.sin(self.shaketime*3)*s, math.cos(self.shaketime)*s,0)
	self.shakemagnitude=self.shakemagnitude-self.shakedamping*dt
	if self.shakemagnitude<0 then self.shakemagnitude=0 end
	
	
	if self.allowzoom and not ui:GetElementAt(ui.cursor:GetPosition()) then
		-- Modify follow (zoom) in response to wheel motion
		-- This modifies the target zoom, or the desired zoom level, not the actual zoom.
		
		local wheel=input:GetMouseMoveWheel()
		self.follow=self.follow-wheel*dt*20
		if self.follow<self.minfollow then self.follow=self.minfollow end
		if self.follow>self.maxfollow then self.follow=self.maxfollow end
	end
	
	if input:GetMouseButtonDown(MOUSEB_MIDDLE) and (self.allowspin or self.allowpitch) then
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
	
	-- Apply the spring function to the zoom (follow) level.
	-- This provides smooth camera movement toward the desired zoom level.
	
	self:SpringFollow(dt)		
	
	if self.clipcamera then
		-- After calculating the camera zoom position, test a ray from view center for obstruction and
		-- clip camera position to nearest obstruction distance.
		local ray=self.camera:GetScreenRay(0.5,0.5)
		local revray=Ray(self.node:GetPosition(), ray.direction*Vector3(-1,-1,-1))
		
		self.curfollow=CameraPick(self.node:GetScene(), revray, self.curfollow)
	end
	
	-- Set camera shake factor (do it here rather than before the camera clipping, so that
	-- shake translations do not affect the casting of the view ray, which could cause
	-- the camera zoom to go haywire
	self.shakenode:SetPosition(shakepos)
	
	if self.springtrack then
		self:SpringPosition(dt)
		self.node:SetPosition(self.newpos)
	else
        self.node:SetPosition(self.newpos)
	end
	
	-- Set camera pitch, zoom and yaw.
	self.node:SetRotation(Quaternion(self.rotangle, Vector3(0,1,0)))
	self.cameranode:SetPosition(Vector3(0,0,-self.curfollow))
	self.anglenode:SetRotation(Quaternion(self.camangle, Vector3(1,0,0)))
end

function ThirdPersonCamera:HandleShakeCamera(eventType, eventData)
	-- Apply some shake factors
	-- Shake is applied via three values
	
	-- magnitude determines the strength of the shake, or maximum deflection, from great big swooping shakes
	-- to small vibrations.
	
	-- speed determines the velocity of the shake vibration
	
	-- damping determines how quickly the shaking fades out.
	
	self.shakemagnitude=eventData:GetFloat("magnitude");
    self.shakespeed=eventData:GetFloat("speed");
    self.shakedamping=eventData:GetFloat("damping");
end

function ThirdPersonCamera:HandleRequestMouseGround(eventType, eventData)
	local dx,dz=self:GetMouseGround()
	
	eventData:SetVector2("location", Vector2(dx,dz))
end

function ThirdPersonCamera:HandleRequestMouseRay(eventType, eventData)
	local ray=self:GetMouseRay()
	eventData:SetVector3("origin", ray.origin)
	eventData:SetVector3("direction", ray.direction)
end

function ThirdPersonCamera:HandleSetCamera(eventType, eventData)
	-- Allow for run-time adjustment of camera parameters.
	
	self.orthographic=eventData("orthographic")
	if self.orthographic then
		self.camera:SetOrthographic(true)
		local w,h=graphics:GetWidth(), graphics:GetHeight()
		self.cellsize=eventData:GetFloat("cellsize")
		self.camera:SetOrthoSize(Vector2(w/(self.cellsize*math.sqrt(2)), h/(self.cellsize*math.sqrt(2))))
	end
	
	self.rotangle=eventData:GetFloat("rotangle")
	self.camangle=eventData:GetFloat("pitchangle")
	self.allowspin=eventData:GetBool("allowspin")
	self.allowzoom=eventData:GetBool("allowzoom")
	if self.allowzoom then
		self.minfollow=eventData:GetFloat("minfollow")
		self.maxfollow=eventData:GetFloat("maxfollow")
	end
end





-- CameraControl
-- Component for controlling the position of the camera.
-- Place this component on the main actor/avatar object in your scene to allow mirroring
-- that object's world translation to the camera root node.

CameraControl=ScriptObject()

function CameraControl:Start()
	self.active=true
	self.offset=1
	self.vm=VariantMap()
    
    self:SubscribeToEvent(self.node, "ActivateCamera", "CameraControl:HandleActivateCamera")
    self:SubscribeToEvent(self.node, "DeactivateCamera", "CameraControl:HandleDeactivateCamera")
end

function CameraControl:TransformChanged()
	--local x,y,z=self.node:GetPositionXYZ()
	local p=self.node:GetPosition()
	self.vm:SetFloat("x", p.x)
	self.vm:SetFloat("y", p.y+self.offset)
	self.vm:SetFloat("z", p.z)
	
	self.node:SendEvent("CameraSetPosition", self.vm)
end

function CameraControl:HandleActivateCamera(eventType, eventData)
    self.active=true
end

function CameraControl:HandleDeactivateCamera(eventType, eventData)
    self.active=false
end