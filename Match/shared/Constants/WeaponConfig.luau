local WeaponConfig = {}

WeaponConfig.TargetKinds = table.freeze({
	Unit = "Unit",
	Structure = "Structure",
})

WeaponConfig.DefaultProjectilePoolSize = 8

WeaponConfig.DefaultTargetPriority = table.freeze({
	WeaponConfig.TargetKinds.Unit,
	WeaponConfig.TargetKinds.Structure,
})

WeaponConfig.Weapons = table.freeze({
	InfantryRifle = table.freeze({
		Id = "InfantryRifle",
		Path = "ReplicatedStorage/Assets/Weapons/InfantryRifle",
		MuzzleName = "Muzzle",
		MuzzlePath = "Handle/Muzzle",
		AttachTo = "RightHand",
		UnitAttachmentName = "RightGripAttachment",
		WeaponAttachmentName = "GripAttachment",
		GripOffset = CFrame.new(),
		Range = 45,
		FireInterval = 0.6,
		ProjectileSpeed = 180,
		Lifetime = 0.5,
		ProjectilePath = "ReplicatedStorage/Assets/Projectiles/InfantryRifleProjectile",
		ProjectilePoolSize = WeaponConfig.DefaultProjectilePoolSize,
		VisualKind = "Bullet",
		Explosive = false,
		TargetPriority = WeaponConfig.DefaultTargetPriority,
		Damage = table.freeze({
			Unit = 12,
			Structure = 6,
		}),
	}),

	TankCannon = table.freeze({
		Id = "TankCannon",
		Path = "",
		Range = 75,
		FireInterval = 2.2,
		ProjectileSpeed = 140,
		Lifetime = 1,
		ProjectilePath = "ReplicatedStorage/Assets/Projectiles/TankCannonProjectile",
		ProjectilePoolSize = WeaponConfig.DefaultProjectilePoolSize,
		Explosive = true,
		ExplosionRadius = 12,
		VisualKind = "ExplosiveShell",
		TargetPriority = WeaponConfig.DefaultTargetPriority,
		Damage = table.freeze({
			Unit = 80,
			Structure = 120,
		}),
	}),
})

function WeaponConfig.GetWeapon(weaponId: any): any?
	if typeof(weaponId) ~= "string" or weaponId == "" then
		return nil
	end

	return WeaponConfig.Weapons[weaponId]
end

return table.freeze(WeaponConfig)
