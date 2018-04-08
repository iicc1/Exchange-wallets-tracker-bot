-- tracker.lua https://github.com/iicc1/Exchange-wallets-tracker-bot
-- Thanks to ethplorer.io for its great api https://github.com/EverexIO/Ethplorer

require('utils')
local config = require('config')
local json = require('cjson')
local redis = require('redis')
local redis = redis.connect('127.0.0.1', 6379)
local https = require('ssl.https')

local ethplorer_key = "?apiKey=freekey"
local ethplorer_endpoint = "https://api.ethplorer.io/getAddressInfo/"
local telegram_token = ""

-- Loading exchange address
for exchange, wallets in pairs(config) do
	for wallet_name, eth_address in pairs(wallets) do
		print("Loading " .. wallet_name .. " (" .. eth_address .. ") from " .. exchange .. " exchange.")
	end
end

-- Polling exchange balances every 5 minutes
local last_time = os.time()
while true do
	if os.time() - last_time > 300 then
		-- Checking token balances
		local tokens = 0
		for exchange, wallets in pairs(config) do
			print("Checking " .. exchange .. " ethereum wallets:")
			for wallet_name, eth_address in pairs(wallets) do
				print(wallet_name .. " (" .. eth_address .. ")")
				local res = https.request(ethplorer_endpoint .. config[exchange][wallet_name] .. ethplorer_key)
				local tab = json.decode(res)
				local balance, name, symbol, price, mk, decimals
				local token_tab, next = tab["tokens"], next
				if not token_tab then break end
				for _, token_tbl in pairs(token_tab) do
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
							local stored_tokens = redis:smembers(exchange)
							local search = false
							for _, tokens_data in pairs(stored_tokens) do
								local symbol_, name_ = string.match(tokens_data, "^(.*):(.*):.*:.*")
								if symbol_ == symbol and name_ == name then
									search = true
									redis:srem(exchange , tokens_data)
								end
							end
							if search then
								-- Token was already there, just update data
								redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price)
							else
								-- New big amount of tokens detected in wallet
								-- Only notifies if the exchange was previously saved
								if redis:exists(exchange) then
									local text = "[" .. exchange .. " - " .. wallet_name .. "] A huge amount of tokens " .. name .. " (" .. symbol .. "), has been transferred to this wallet. The total value of this tokens in the wallet is now " .. wallet_value .. "$. https://etherscan.io/address/" .. eth_address
									print(text)
									-- just a test
									https.request("https://api.telegram.org/bot" .. telegram_token .. "/sendMessage?chat_id=6722095&text=" .. text)
									redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price)
								end
							end
						end
					end
					tokens =  tokens + 1
				end
			end
		end
		print("Completed: " .. tokens .. " tokens scanned.")
		last_time = os.time()
	end
end