-- Token-bucket rate limiter per player (Master Plan §23, Appendix C).

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxTokens: number, refillPerSec: number)
	return setmetatable({ max = maxTokens, rate = refillPerSec, buckets = {} }, RateLimiter)
end

function RateLimiter:Check(key: any): boolean
	local now = os.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.max, t = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.max, b.tokens + (now - b.t) * self.rate)
	b.t = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Remove(key: any)
	self.buckets[key] = nil
end

return RateLimiter
