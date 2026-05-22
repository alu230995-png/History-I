local MatchDateUtils = {}

local DAYS_PER_MONTH = table.freeze({
	31,
	28,
	31,
	30,
	31,
	30,
	31,
	31,
	30,
	31,
	30,
	31,
})

function MatchDateUtils.IsLeapYear(year: number): boolean
	return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

function MatchDateUtils.GetDaysInMonth(year: number, month: number): number
	if month == 2 and MatchDateUtils.IsLeapYear(year) then
		return 29
	end

	return DAYS_PER_MONTH[month] or DAYS_PER_MONTH[1]
end

function MatchDateUtils.AdvanceOneDay(year: number, month: number, day: number): (number, number, number)
	local nextDay = day + 1
	if nextDay <= MatchDateUtils.GetDaysInMonth(year, month) then
		return year, month, nextDay
	end

	local nextMonth = month + 1
	if nextMonth <= 12 then
		return year, nextMonth, 1
	end

	return year + 1, 1, 1
end

return table.freeze(MatchDateUtils)
