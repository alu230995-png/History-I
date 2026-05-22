local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local CollisionService = Knit.CreateService({
	Name = "CollisionService",
	Client = {},
})

local MIN_SEGMENT_LENGTH_SQUARED = 0.000001

local function getSegmentHitAlpha(fromPosition: Vector3, toPosition: Vector3, center: Vector3, radius: number): number?
	local segment = toPosition - fromPosition
	local segmentLengthSquared = segment:Dot(segment)
	if segmentLengthSquared <= MIN_SEGMENT_LENGTH_SQUARED then
		return nil
	end

	local offset = center - fromPosition
	local alpha = math.clamp(offset:Dot(segment) / segmentLengthSquared, 0, 1)
	local closest = fromPosition + (segment * alpha)
	local hitOffset = center - closest
	if hitOffset:Dot(hitOffset) > radius * radius then
		return nil
	end

	return alpha
end

function CollisionService:KnitInit()
	self._targetingService = nil
end

function CollisionService:KnitStart()
	self._targetingService = Knit.GetService("TargetingService")
end

function CollisionService:SweepProjectile(
	projectile,
	fromPosition: Vector3,
	toPosition: Vector3,
	now: number
): (any?, Vector3?)
	local closestTarget = nil
	local closestAlpha = math.huge
	local targets = self._targetingService:GetTargets()

	for index = 1, #targets do
		local target = targets[index]
		local targetPosition = self._targetingService:GetProjectileTargetPosition(target, projectile, now)
		if targetPosition == nil then
			continue
		end

		local hitAlpha = getSegmentHitAlpha(fromPosition, toPosition, targetPosition, target.HitRadius)
		if hitAlpha ~= nil and hitAlpha < closestAlpha then
			closestAlpha = hitAlpha
			closestTarget = target
		end
	end

	return closestTarget, if closestTarget ~= nil then fromPosition:Lerp(toPosition, closestAlpha) else nil
end

return CollisionService
