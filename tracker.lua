-- tracker.lua https://github.com/iicc1/Exchange-wallets-tracker-bot

require('utils')
local config = require('config')
local json = require('cjson')
local redis = require('redis')
local redis = redis.connect('127.0.0.1', 6379)
local https = require('ssl.https')

local ethplorer_key = "?apiKey=freekey"
local ethplorer_endpoint = "https://api.ethplorer.io/getAddressInfo/"

-- Loading exchange address
for exchange, wallets in pairs(config) do
	for wallet_name, eth_address in pairs(wallets) do
		print("Loading " .. wallet_name .. " (" .. eth_address .. ") from " .. exchange .. " exchange.")
	end
end

-- Checking token balances
local tokens = 0
for exchange, wallets in pairs(config) do
	print("Checking " .. exchange .. " ethereum wallets:")
	for wallet_name, eth_address in pairs(wallets) do
		print("For " .. wallet_name .. "(" .. eth_address .. ")")
		local res = https.request(ethplorer_endpoint .. config[exchange][wallet_name] .. ethplorer_key)
		local tab = json.decode(res)
		local balance, name, symbol, price, mk, decimalsc
		for _, token_tbl in pairs(tab["tokens"]) do
			for general, info in pairs(token_tbl) do
				if general == "balance" then balance = info
				elseif general == "tokenInfo" then
					for data, value in pairs(info) do
						if data == "name" then name = value
						elseif data == "symbol" then symbol = value
						elseif data == "decimals" then decimals = tonumber(value)
						elseif data == "price" and type(value) == "table" then
							for data_price, value_price in pairs(value) do
								if data_price == "rate" then price = value_price
								elseif data_price == "marketCapUsd" then mk = value_price end
							end
						elseif data == "price" and type(value) ~= "table" then
							price = nil
							mk = nil
						end
					end
				end
			end
			if decimals > 1 then
				while decimals > 0 do
					balance = balance / 10
					decimals = decimals -1
				end
			end
			if type(price) == "string" then
				local wallet_value = tonumber(balance) * tonumber(price)
				-- If there is a significant value of a token in the wallet, then probably listed
				if wallet_value > 100000 then
					-- Checks if it was a huge amount of tokens in the previous checks
					local stored_tokens = redis:smembers(exchange .. ":" .. wallet_name)
					local search = false
					for _, tokens_data in pairs(stored_tokens) do
						if string.find(tokens_data, name) and  string.find(tokens_data, symbol) then
							search = true
							redis:srem(exchange .. ":" .. wallet_name, tokens_data)
						end
					end
					if search then
						-- Token was already there, just update data
						redis:sadd(exchange .. ":" .. wallet_name, symbol .. ":" .. name .. ":" .. balance .. ":" .. price)
					else
						-- New big amount of tokens detected in wallet
						print("A huge amount of tokens " .. name .. " (" .. symbol .. "), has been transfered to this wallet. The total value of this tokens in the wallet is now " .. wallet_value .. "$.")
						redis:sadd(exchange .. ":" .. wallet_name, symbol .. ":" .. name .. ":" .. balance .. ":" .. price)
					end
				end
			end
			tokens =  tokens + 1
		end
	end
end
print("Completed: " .. tokens .. " tokens scanned.")