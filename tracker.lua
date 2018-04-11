-- tracker.lua https://github.com/iicc1/Exchange-wallets-tracker-bot
-- Thanks to ethplorer.io for its great api

require('utils')
local config = require('config')
local json = require('cjson')
local redis = require('redis')
local redis = redis.connect('127.0.0.1', 6379)
local https = require('ssl.https')

local ethplorer_key = "?apiKey=freekey"
local ethplorer_endpoint = "https://api.ethplorer.io/getAddressInfo/"
local telegram_token = ""
local testing_id = ""	-- Your telegram id 

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
			local new_exchange = false
			if not redis:exists(exchange) then
				new_exchange = true
			end
			for wallet_name, eth_address in pairs(wallets) do
				print(wallet_name .. " (" .. eth_address .. ")")
				local res = https.request(ethplorer_endpoint .. config[exchange][wallet_name] .. ethplorer_key)
				if not res then
					break
				end
				local tab = json.decode(res)
				if tab["error"] then
					print(res)
					break
				end
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
					print(symbol)
					if type(price) == "string" then
						local wallet_value = tonumber(balance) * tonumber(price)
						local amount
						-- If there is a significant value of a token in the wallet, then probably listed
						if wallet_value > 10000 then
							if wallet_value > 100000 then
								amount = 100
							else
								amount = 10
								--print(symbol, amount)
							end
							-- Checks if it was a huge amount of tokens in the previous checks
							local stored_tokens = redis:smembers(exchange)
							local searched = false
							for _, tokens_data in pairs(stored_tokens) do
								local symbol_, name_, amount_ = string.match(tokens_data, "^(.*):(.*):.*:.*:(.*)")
								if symbol_ == symbol and name_ == name then
									if tonumber(amount_) >= amount then
										searched = true
										amount = amount_
									end
									redis:srem(exchange , tokens_data)
								end
							end
							if searched then
								-- Token was already there, just update data
								redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price .. ":" .. amount)
							else
								-- Avoid sending many messages when a exchange is added
								if not new_exchange then
									local text = {}
									text[1] = "🚀 *New tokens detected in a selected exchange wallet!*\n"
									text[2] = "*• Token:* " .. name .. " (" .. symbol .. ")\n"
									text[3] = "*• Exchange:* " .. exchange .. "\n"
									text[4] = "*• Wallet:* " .. wallet_name .. " (`" .. eth_address .. "`)\n"
									text[5] = "*• Balance:* " .. balance .. " tokens\n"
									text[6] = "*• Token price:* $" .. price .. "\n"
									text[7] = "*• Total token value in wallet:* $" .. wallet_value .. "\n\n"
									text[8] = "[Ethplorer](https://ethplorer.io/address/" .. eth_address .. ") - [Etherscan](https://etherscan.io/address/" .. eth_address .. ") - [Etherchain](https://www.etherchain.org/account/" .. eth_address .. ") - [CoinMarketCap](https://coinmarketcap.com/search/?q=" .. symbol .. ") - [CoinCheckup](https://coincheckup.com/)"
									text = table.concat(text)
									print("Attention: new token in " .. exchange, symbol)
									https.request("https://api.telegram.org/bot" .. telegram_token .. "/sendMessage?chat_id=" .. testing_id .. "&text=" .. urlencode(text) .. "&parse_mode=Markdown&disable_web_page_preview=true")
								else
									print("New coin in a nex exchange, skipping...")
								end
								redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price .. ":" .. amount)
							end
						end
					end
					tokens =  tokens + 1
				end
			end
		end
		print(os.date(), "------------ Completed: " .. tokens .. " tokens scanned --------------")
		last_time = os.time()
	end
end