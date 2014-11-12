-- Pixel-art isometric block demo
require 'thirdpersoncamera'
require 'objectinstancing'

local startupobjects=
{
    {
		Position={x=0,y=0,z=0},
		Children=
		{
			{
				Direction={x=1.5, y=-2, z=0.1},
				Components=
				{
					{Type="Light", LightType=LIGHT_DIRECTIONAL, Color={r=1.15*0.25, g=1.1*0.25, b=1.05*0.25}}
					
				}
			},
			{
				Direction={x=-1.5, y=-2, z=-0.1},
				Components=
				{
					{Type="Light", LightType=LIGHT_DIRECTIONAL, Color={b=1.15*0.25, g=1.1*0.25, r=1.05*0.25},CastShadows=true,
						ShadowBias={ConstantBias=0.001, SlopeScaledBias=0.6},
						ShadowCascade={Split1=2, Split2=10, Split3=30, Split4=50, FadeStart=0.8}}
				}
			}
		},
		Components=
		{
			{Type="Zone", AmbientColor={b=111/255*0.225, g=70/255*0.225, r=26/255*0.225}, FogColor={b=111/255*0.225, g=70/255*0.225, r=26/255*0.225}, FogStart=40, FogEnd=60, BoundingBox=BoundingBox(-1000,1000)},
			{Type="Skybox", Model="Models/SkySphere.mdl", Material="Materials/nightsky.xml"},
		}
	
    },
    
    {
		Components=
		{
			{Type="ScriptObject", Classname="ThirdPersonCamera", Parameters={clipcamera=false, springtrack=true, orthographic=true, cellsize=64/math.sqrt(2), allowspin=false, allowzoom=false, allowpitch=false, camangle=30, rotangle=-45}},
		}
	},
    
    {
        Components=
        {
            {Type="StaticModel", Model="Models/isocube.mdl", Material="Materials/block_stone.xml"}
        }
    },
    
    {
        Position={x=1,y=0,z=0},
        Components=
        {
            {Type="StaticModel", Model="Models/isocube.mdl", Material="Materials/block_dirt.xml"}
        }
    },
    
    {
        Position={x=1,y=0.808,z=0},
        Components=
        {
            {Type="StaticModel", Model="Models/isocube.mdl", Material="Materials/block_grass.xml"}
        }
    }
}

objectcache={}


function Start()
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("Update", "Update")
    
    local style = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    local cursor = Cursor:new()
    cursor:SetStyleAuto(style)
    ui.cursor = cursor
    -- Set starting position of the cursor at the rendering window center
    cursor:SetPosition(graphics.width / 2, graphics.height / 2)
    
    scene=Scene()
    scene:CreateComponent("Octree")
    
    local o
    for _,o in ipairs(startupobjects) do table.insert(objectcache,InstanceObject(o,scene)) end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
	local vm=VariantMap()
	-- Close console (if open) or exit when ESC is pressed
	if key == KEY_ESC then
        local engine = GetEngine()
		engine:Exit()
	elseif key==KEY_P then
		local t=os.date("*t")
		local filename="screen_"..tostring(t.year).."_"..tostring(t.month).."_"..tostring(t.day).."_"..tostring(t.hour).."_"..tostring(t.min).."_"..tostring(t.sec)..".png"
		local img=Image()
		graphics:TakeScreenShot(img)
		img:SavePNG(filename)
	end
end