local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local humanoid = character:WaitForChild("Humanoid")

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local camera = game.Workspace.CurrentCamera
local aimCF = CFrame.new()
local originalCameraCF = camera.CFrame  -- Declare this near the top of your script

local mouse = player:GetMouse()

local isAiming = false;
local isShooting = false;
local isReloading = false;
local isSprinting = false;
local canShoot = true;
local canReload = true;

local debounce = false;

local bobOffset = CFrame.new()

local currentSwayAMT = 0
local swayAMT = -.3
local aimSwayAMT = .2
local swayCF = CFrame.new()
local lastCameraCF = CFrame.new()

local fireAnim = nil
local equipAnim = nil
local deequipAnim = nil
local emptyFireAnim = nil
local reloadAnim = nil
local emptyReloadAnim = nil
local tpIdleAnim = nil

local oldCamCF = CFrame.new()

local recoilStrength = 1  -- Adjust this value for more or less recoil
local recoilRecoverySpeed = 0.05  -- How quickly the camera returns to original position

local hud = player.PlayerGui:WaitForChild("HUD")
local hudHM = player.PlayerGui:WaitForChild("HitMarker")

hudHM.Frame.ImageLabel.Visible = false


local framework = {
	inventory = {
		"M4A1";
		"M4A1S";
		"M9";
		"Knife";
		"Frag";
	};
	
	loadouts = {
		loadout1 = {
			"M4A1";
			"M9";
			"Knife";
			"Frag";
		};
		loadout2 = {
			"M4A1S";
			"M9";
			"Knife";
			"Frag";
		};
	};
	module = nil;
	viewmodel = nil;
	currentSlot = 1;
}
--------------------------------------
--FUNCTIONS--
--------------------------------------

function m4a1sapplyRecoil()
	-- Save the original camera position before applying recoil
	originalCameraCF = camera.CFrame

	-- Apply fixed upward recoil by rotating around the X-axis
	local verticalRecoil = CFrame.Angles(math.rad(0.1), 0, 0)

	-- Combine vertical recoil with the original camera orientation
	camera.CFrame = originalCameraCF * verticalRecoil

	-- Smoothly return to aiming orientation
	task.spawn(function()
		local start = tick()
		repeat
			local now = tick()
			local alpha = (now - start) / recoilRecoverySpeed
			local newOrientation = getAimOrientation()
			camera.CFrame = camera.CFrame:Lerp(newOrientation, alpha)
			task.wait()
		until alpha >= 1
	end)
end

function applyRecoil()
	-- Save the original camera position before applying recoil
	originalCameraCF = camera.CFrame

	-- Randomize horizontal recoil between a minimum and maximum range
	local minHorizontalRecoil = -1  -- Minimum horizontal recoil (in degrees)
	local maxHorizontalRecoil = 1   -- Maximum horizontal recoil (in degrees)
	local randomHorizontalRecoil = math.rad(math.random(minHorizontalRecoil, maxHorizontalRecoil))

	-- Apply fixed upward recoil and randomized horizontal recoil
	local verticalRecoil = CFrame.Angles(math.rad(recoilStrength), randomHorizontalRecoil, 0)

	-- Combine vertical and horizontal recoil with the original camera orientation
	camera.CFrame = originalCameraCF * verticalRecoil

	-- Smoothly return to aiming orientation
	task.spawn(function()
		local start = tick()
		repeat
			local now = tick()
			local alpha = (now - start) / recoilRecoverySpeed
			local newOrientation = getAimOrientation()
			camera.CFrame = camera.CFrame:Lerp(newOrientation, alpha)
			task.wait()
		until alpha >= 1
	end)
end

function getAimOrientation()
	-- Example implementation: Pointing towards the mouse hit position
	local targetPosition = mouse.Hit.p
	return CFrame.new(camera.CFrame.Position, targetPosition)
end

local function initializeAnimation(model, animName, animId)
	local anim = Instance.new("Animation")
	anim.Name = animName
	anim.AnimationId = animId

	if model:IsA("Humanoid") then
		-- If the model is a Humanoid, treat it as a third-person animation
		anim.Parent = model.Parent -- Parent the animation to the character model
		return model:LoadAnimation(anim) -- Load the animation onto the humanoid
	else
		-- If the model is not a Humanoid, treat it as a viewmodel animation
		anim.Parent = model
		return model.AnimationController.Animator:LoadAnimation(anim)
	end
end


local function stopAllAnimations()
	local animations = {equipAnim, fireAnim, emptyFireAnim, reloadAnim, deequipAnim}
	for _, anim in pairs(animations) do
		if anim and anim.IsPlaying then
			anim:Stop()
		end
	end
end

local function replaceViewModel(newModel)
	for _, child in pairs(camera:GetChildren()) do 
		if child:IsA("Model") then
			deequipAnim:Play()
			repeat task.wait() until not deequipAnim.IsPlaying
			child:Destroy()
		end
	end
	newModel.Parent = camera
end

function loadSlot(Item)
	canShoot = false
	stopAllAnimations()

	local moduleScript = game.ReplicatedStorage.Modules.Primary:FindFirstChild(Item) or game.ReplicatedStorage.Modules.Secondary:FindFirstChild(Item)
	local viewModelModel = game.ReplicatedStorage.Viewmodels:FindFirstChild(Item)
	
	

	if moduleScript and viewModelModel then
		framework.module = require(moduleScript)
		framework.viewmodel = viewModelModel:Clone()
		
		for i, v in pairs(moduleScript:GetDescendants()) do
			if v.Name == Item then
				framework.module = require(v)
			end
		end

		replaceViewModel(framework.viewmodel)

		-- Initialize animations
		fireAnim = initializeAnimation(framework.viewmodel, "Fire", framework.module.fireAnim)
		emptyFireAnim = initializeAnimation(framework.viewmodel, "EmptyFire", framework.module.emptyFireAnim)
		equipAnim = initializeAnimation(framework.viewmodel, "Equip", framework.module.equipAnim)
		reloadAnim = initializeAnimation(framework.viewmodel, "Reload", framework.module.reloadAnim)
		emptyReloadAnim = initializeAnimation(framework.viewmodel, "EmptyReload", framework.module.emptyReloadAnim)
		deequipAnim = initializeAnimation(framework.viewmodel, "Deequip", framework.module.deequipAnim)

		
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("Humanoid not found in character")
			return
		end

		-- Initialize tpIdleAnim for the humanoid
		if framework.module.tpIdleAnim then
			tpIdleAnim = initializeAnimation(humanoid, "IdleAnim", framework.module.tpIdleAnim)
			tpIdleAnim:Play()
		else
			warn("tpIdleAnim ID not found in framework.module")
		end
		
		game.ReplicatedStorage.Events.LoadSlot:FireServer(Item, framework.module.fireSound.SoundId, framework.module.fireSound.Volume)

		-- Set initial transparency for the viewmodel parts
		for _, part in pairs(framework.viewmodel:GetDescendants()) do
			if part:IsA("Part") or part:IsA("MeshPart") or part:IsA("BasePart") then 
				part.Transparency = 1
			end
		end

		equipAnim:Play()
		task.wait(.1)  -- Adjust this wait time as needed

		-- Set final transparency for the viewmodel parts
		for _, part in pairs(framework.viewmodel:GetDescendants()) do
			if part:IsA("Part") or part:IsA("MeshPart") or part:IsA("BasePart") then 
				if part.Name == "Main" or part.Name == "Muzzle" or part.Name == "FakeCamera" or part.Name == "AimPart" or part.Name == "HumanoidRootPart" then
					-- Skip these parts
				else
					part.Transparency = 0                                
				end 
			end
		end

		canShoot = true
	else
		warn("Module or ViewModel not found for item: " .. Item)
	end
end

function Reload()
	if canReload then
		if isReloading == false then
			canShoot = false
			isReloading = true

			fireAnim:Stop()	
			emptyFireAnim:Stop()
			equipAnim:Stop()

			if framework.module.ammo > 0 then
				reloadAnim:Play()
			else
				emptyReloadAnim:Play()
			end

			wait(framework.module.reloadTime)

			canShoot = true
			isReloading = false

			framework.module.ammo = framework.module.maxAmmo
		end
	end
end

function Shoot()
	if framework.module.fireMode == "Semi" then
		equipAnim:Stop()
		reloadAnim:Stop()
		emptyReloadAnim:Stop()

		if framework.module.ammo == 0 then
			fireAnim:Stop()
			emptyFireAnim:Play()
		else
			emptyFireAnim:Stop()
			fireAnim:Play()
		end

		framework.module.ammo -= 1

		game.ReplicatedStorage.Events.Shoot:FireServer(framework.viewmodel.Muzzle.Position, mouse.Hit.p, framework.module.damage, framework.module.headshot)

		applyRecoil()

		if framework.module.ammo == 0 then
			task.wait(.15)
			Reload()
			repeat task.wait() until emptyReloadAnim.IsPlaying == false
			debounce = false
		else
			debounce = true

			wait (framework.module.debounce)

			debounce = false
		end
	end

	if framework.module.fireMode == "Full Auto" then
		isShooting = true
		while isShooting and framework.module.ammo > 0 and isReloading ~= true and canShoot == true do
			equipAnim:Stop()
			reloadAnim:Stop()
			fireAnim:Play()

			if framework.module.ammo == 0 then
				fireAnim:Stop()
				emptyFireAnim:Play()
			else
				emptyFireAnim:Stop()
				fireAnim:Play()
			end

			framework.module.ammo -= 1

			game.ReplicatedStorage.Events.Shoot:FireServer(framework.viewmodel.Muzzle.Position, mouse.Hit.p, framework.module.damage, framework.module.headshot)

			-- Apply recoil after each shot
			if framework.viewmodel.Name == "M4A1S" then
				m4a1sapplyRecoil()
			else
				applyRecoil()
			end


			if framework.module.ammo == 0 then
				task.wait(.15)
				Reload()
			end

			wait(framework.module.fireRate)

			-- [Any additional code needed for full-auto firing...]
		end
	end
end

function updateCameraShake()
	if framework.module and framework.viewmodel then
		local newCamCF = framework.viewmodel.FakeCamera.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
		camera.CFrame = camera.CFrame * newCamCF:ToObjectSpace(oldCamCF)
		oldCamCF = newCamCF
	end
end

function showHitmarker()	
	if player.Character and player.Character:FindFirstChild("UpperTorso") then
		-- Remove any existing hit marker sounds
		for _, v in pairs(player.Character.UpperTorso:GetChildren()) do
			if v.Name == "HitMarkerSound" then
				v:Destroy()
			end
		end

		-- Create and set up the hit marker sound
		local hitSound = Instance.new("Sound")
		hitSound.Parent = player.Character.UpperTorso
		hitSound.Name = "HitMarkerSound"
		hitSound.SoundId = "rbxassetid://160432334" -- Replace with your sound asset ID
		hitSound.Volume = 1 -- Set volume as needed

		-- Play the sound
		hitSound:Play()

		-- Show hit marker HUD
		hudHM.Frame.ImageLabel.Visible = true
		wait(0.5)
		hudHM.Frame.ImageLabel.Visible = false
	end
end

local menu = player.PlayerGui:WaitForChild("Menu")

local currentLoadout = 1
local currentWeapon = ""

local currentClass = ""

menu.LoadoutMenu.Loadout1.MouseButton1Click:Connect(function()
	menu.LoadoutMenu.PrimaryWeapon.Text = framework.loadouts.loadout1[1]
	menu.LoadoutMenu.SecondaryWeapon.Text = framework.loadouts.loadout1[2]
	menu.LoadoutMenu.Knife.Text = framework.loadouts.loadout1[3]
	menu.LoadoutMenu.Grenade.Text = framework.loadouts.loadout1[4]
	currentLoadout = 1
end)

menu.LoadoutMenu.Loadout2.MouseButton1Click:Connect(function()
	menu.LoadoutMenu.PrimaryWeapon.Text = framework.loadouts.loadout2[1]
	menu.LoadoutMenu.SecondaryWeapon.Text = framework.loadouts.loadout2[2]
	menu.LoadoutMenu.Knife.Text = framework.loadouts.loadout2[3]
	menu.LoadoutMenu.Grenade.Text = framework.loadouts.loadout2[4]
	currentLoadout = 2
end)

menu.LoadoutMenu.Select.MouseButton1Click:Connect(function()
	for i, v in pairs(framework.loadouts) do
		if string.find(i, tostring(currentLoadout)) then
			framework.inventory[1] = v[1]
			framework.inventory[2] = v[2]
			framework.inventory[3] = v[3]
			framework.inventory[4] = v[4]
		end
	end
	
	menu.LoadoutMenu.Visible = false
	
	loadSlot(framework.inventory[1])

end)

menu.LoadoutMenu.Customize.MouseButton1Click:Connect(function()
	for i, v in pairs(framework.loadouts) do
		if string.find(i, tostring(currentLoadout)) then
			menu.CustomizeMenu.PrimaryWeapon.Text = v[1]
			menu.CustomizeMenu.SecondaryWeapon.Text = v[2]
			menu.CustomizeMenu.Knife.Text = v[3]
			menu.CustomizeMenu.Grenade.Text = v[4]
		end
	end
	
	menu.CustomizeMenu.SelectedClass.Text = "Please select a weapon!"
	menu.CustomizeMenu.SelectedWeapon.Text = "No weapon selected"
	
	currentClass = ""
	currentWeapon = ""
	
	menu.CustomizeMenu.Change.Visible = false
	menu.CustomizeMenu.Attachments.Visible = false
	
	menu.CustomizeMenu.ScrollingFrame.Visible = false
	menu.CustomizeMenu.ChooseAWeapon.Visible = false
	
	for i, v in pairs(menu.CustomizeMenu.ScrollingFrame:GetChildren()) do
		if v:IsA("TextButton") then
			v:Destroy()
		end
	end

	menu.LoadoutMenu.Visible = false
	menu.CustomizeMenu.Visible = true
end)



menu.CustomizeMenu.PrimaryButton.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.SelectedClass.Text = "Primary"
	menu.CustomizeMenu.SelectedWeapon.Text = menu.CustomizeMenu.PrimaryWeapon.Text
	
	menu.CustomizeMenu.Change.Visible = true
	menu.CustomizeMenu.Attachments.Visible = true
	
	currentClass = "Primary"
end)

menu.CustomizeMenu.SecondaryButton.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.SelectedClass.Text = "Secondary"
	menu.CustomizeMenu.SelectedWeapon.Text = menu.CustomizeMenu.SecondaryWeapon.Text
	
	menu.CustomizeMenu.Change.Visible = true
	menu.CustomizeMenu.Attachments.Visible = true
	
	currentClass = "Secondary"
end)

menu.CustomizeMenu.ThrowableButton.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.SelectedClass.Text = "Throwable"
	menu.CustomizeMenu.SelectedWeapon.Text = menu.CustomizeMenu.Grenade.Text
	
	menu.CustomizeMenu.Change.Visible = true
	menu.CustomizeMenu.Attachments.Visible = true
	
	currentClass = "Throwable"
end)

menu.CustomizeMenu.MeleeButton.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.SelectedClass.Text = "Melee"
	menu.CustomizeMenu.SelectedWeapon.Text = menu.CustomizeMenu.Knife.Text
	
	menu.CustomizeMenu.Change.Visible = true
	menu.CustomizeMenu.Attachments.Visible = true
	
	currentClass = "Melee"
end)

menu.CustomizeMenu.Confirm.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.Visible = false
	menu.LoadoutMenu.Visible = true
end)

menu.CustomizeMenu.Change.MouseButton1Click:Connect(function()
	menu.CustomizeMenu.ScrollingFrame.Visible = true
	menu.CustomizeMenu.ChooseAWeapon.Visible = true
	
	for i, v in pairs(menu.CustomizeMenu.ScrollingFrame:GetChildren()) do
		if v:IsA("TextButton") then
			v:Destroy()
		end
	end
	
	for i, v in pairs(game.ReplicatedStorage.Modules:FindFirstChild(currentClass):GetChildren()) do
		local selectWeapon = game.ReplicatedStorage.GUI.WeaponSelect:Clone()
		selectWeapon.Parent = menu.CustomizeMenu.ScrollingFrame
		selectWeapon.Name = v.Name
		selectWeapon.Text = v.Name
	end
end)


RunService.RenderStepped:Connect(function()


	mouse.TargetFilter = framework.viewmodel
	
	-- Initialize a flag to keep track of whether any frame is visible
	local anyFrameVisible = false

	-- Check each child of the menu to see if it's a Frame and if it's visible
	for _, v in pairs(menu:GetChildren()) do
		if v:IsA("Frame") and v.Visible then
			anyFrameVisible = true
			break  -- Exit the loop as soon as one visible frame is found
		end
	end

	-- Set MouseIconEnabled and modal based on whether any frame is visible
	UserInputService.MouseIconEnabled = anyFrameVisible
	canShoot = not anyFrameVisible
	canReload = not anyFrameVisible
	menu.TextButton.Modal = anyFrameVisible

	if humanoid then 
		local rot = camera.CFrame:ToObjectSpace(lastCameraCF)
		local X,Y,Z = rot:ToOrientation()
		swayCF = swayCF:Lerp(CFrame.Angles(math.sin(X) * currentSwayAMT, math.sin(Y) * currentSwayAMT, 0), .1)
		lastCameraCF = camera.CFrame

		if hud and humanoid then
			if framework.viewmodel and framework.module then
				hud.GunName.Text = framework.inventory[framework.currentSlot]
				hud.Ammo.Text = framework.module.ammo
				hud.Ammo.MaxAmmo.Text = framework.module.maxAmmo
			end
		end




		if humanoid then

			if framework.viewmodel ~= nil and framework.module ~= nil then
				if humanoid.MoveDirection.Magnitude > 0 then
					if humanoid.WalkSpeed == 13 then 
						bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() *4) * .05, -humanoid.CameraOffset.Y/3, 0) * CFrame.Angles(0, math.sin(tick() * -4) * -.05, math.cos(tick() * -4) * -.05), .1)
						isSprinting = false
					elseif humanoid.WalkSpeed == 20 then
						bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() *8) * .1, -humanoid.CameraOffset.Y/3, 0) * CFrame.Angles(0, math.sin(tick() * -8) * -.1, math.cos(tick() * -8) * .1) * framework.module.sprintCF, .1)
						isSprinting = true
					end
				else
					bobOffset = bobOffset:Lerp(CFrame.new(0, -humanoid.CameraOffset.Y/3, 0), .1)
					isSprinting = false
				end
			end

			for i, v in pairs(camera:GetChildren()) do
				if v:IsA("Model") then
					v:SetPrimaryPartCFrame(camera.CFrame * swayCF * aimCF * bobOffset)
					updateCameraShake()
				end
			end
		end

		if isAiming and framework.viewmodel ~= nil and framework.module.canAim and isSprinting == false then
			local offset = framework.viewmodel.AimPart.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
			aimCF = aimCF:Lerp(offset, framework.module.aimSmooth)
			currentSwayAMT = aimSwayAMT
		else
			local offset = CFrame.new()
			aimCF = aimCF:Lerp(offset, framework.module.aimSmooth)
			currentSwayAMT = swayAMT
		end
	end
end)

UserInputService.MouseIconEnabled = false

UserInputService.InputBegan:Connect(function(input)

	if input.KeyCode == Enum.KeyCode.One then
		if framework.currentSlot ~= 1 and isReloading == false then
			loadSlot(framework.inventory[1])
			framework.currentSlot = 1
		end
	end

	if input.KeyCode == Enum.KeyCode.Two then
		if framework.currentSlot ~= 2 and isReloading == false then
			loadSlot(framework.inventory[2])
			framework.currentSlot = 2
		end
	end
	if input.KeyCode == Enum.KeyCode.Three then
		if framework.currentSlot ~= 3 and isReloading == false then
			loadSlot(framework.inventory[3])
			framework.currentSlot = 3
		end
	end

	if input.KeyCode == Enum.KeyCode.Four then
		if framework.currentSlot ~= 4 and isReloading == false then
			loadSlot(framework.inventory[4])
			framework.currentSlot = 4
		end
	end



	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local offset = framework.viewmodel.AimPart.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
		aimCF = aimCF:Lerp(offset, .1)
		isAiming = true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if character and framework.viewmodel and framework.module and canShoot == true then
			if framework.module.ammo > 0 and isReloading ~= true then
				if not isShooting and framework.module.fireMode == "Full Auto" then
					isShooting = true
					while isShooting and framework.module.ammo > 0 and isReloading ~= true and canShoot == true do
						Shoot()
						wait(framework.module.fireRate)
					end
				else
					Shoot()
				end
			else
				emptyFireAnim:Play()
			end
		end
	end

	if input.KeyCode == Enum.KeyCode.R then
		Reload()
	end

end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = false
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isShooting = false
	end
end)

game.ReplicatedStorage.Events.PlayerAdded.OnClientEvent:Connect(function(ply, char)
	
	menu.LoadoutMenu.Visible = true
	menu.CustomizeMenu.Visible = false
	player = game.Players.LocalPlayer
	character = player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	hud = player.PlayerGui:WaitForChild("HUD")
	hudHM = player.PlayerGui:WaitForChild("HitMarker")
	hudHM.Frame.ImageLabel.Visible = false
	
	

	for _, itemName in pairs(framework.inventory) do
		-- Find the module for the current inventory item
		local moduleScript = game.ReplicatedStorage.Modules:FindFirstChild(itemName)
		if moduleScript then
			-- Require the module to access its properties
			local module = require(moduleScript)
			-- Check if the module has an 'ammo' and 'maxAmmo' property
			if module.ammo and module.maxAmmo then
				-- Reset the ammo to maxAmmo for the module
				module.ammo = module.maxAmmo
				print(module.ammo)
				print(module.maxAmmo)
			end
		end
	end


	humanoid.Died:Connect(function()

		framework.module.ammo = framework.module.maxAmmo
		print("Died")
		player = nil
		character = nil
		humanoid = nil

		local camera = game.Workspace.CurrentCamera
		local aimCF = CFrame.new()

		local isAiming = false;
		local isShooting = false;
		local isReloading = false;
		local isSprinting = false;
		local canShoot = false;
		local canReload = false;

		local debounce = false;

		local bobOffset = CFrame.new()

		local currentSwayAMT = 0
		local swayAMT = -.3
		local aimSwayAMT = .2
		local swayCF = CFrame.new()
		local lastCameraCF = CFrame.new()

		local fireAnim = nil

		if camera:FindFirstChildWhichIsA("Model") then
			camera:FindFirstChildWhichIsA("Model"):Destroy()
		end

	end)
end)

game.ReplicatedStorage.Events.HitMarker.OnClientEvent:Connect(showHitmarker)


