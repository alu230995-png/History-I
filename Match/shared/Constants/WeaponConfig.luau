local WeaponConfig = {}

WeaponConfig.TargetKinds = table.freeze({
	Unit = "Unit",
	Structure = "Structure",
})

WeaponConfig.Weapons = table.freeze({
	InfantryRifle = table.freeze({
		Id = "InfantryRifle",
		Range = 45,
		FireInterval = 0.6,
		ProjectileSpeed = 180,
		Lifetime = 0.5,
		Damage = table.freeze({
			Unit = 12,
			Structure = 6,
		}),
	}),

	TankCannon = table.freeze({
		Id = "TankCannon",
		Range = 75,
		FireInterval = 2.2,
		ProjectileSpeed = 140,
		Lifetime = 1,
		ExplosionRadius = 12,
		VisualKind = "ExplosiveShell",
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
