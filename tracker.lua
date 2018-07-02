-- tracker.lua https://github.com/iicc1/Exchange-wallets-tracker-bot
-- Thanks to ethplorer.io and etherscan.io for their great api

require('utils')
local config = require('config')
local json = require('cjson')
local redis = require('redis')
local redis = redis.connect('127.0.0.1', 6379)
local https = require('ssl.https')

local ethplorer_key = "?apiKey=freekey"  -- Free ethplorer api
local ethplorer_endpoint = "https://api.ethplorer.io/getAddressInfo/"
local etherscan_key = ""  -- Not really needed
local etherscan_endpoint = "https://api.etherscan.io/api?module=account&action=tokentx&contractaddress=%s&address=%s&page=1&offset=1&sort=desc&apikey=" .. etherscan_key
local telegram_token = ""  -- The Telegram token of your bot created with @BotFather
local testing_id = ""  -- Your telegram id for testing, it can be an user, chat, channel, etc.

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
				print("", wallet_name .. " (" .. eth_address .. ")")
				local res = https.request(ethplorer_endpoint .. config[exchange][wallet_name] .. ethplorer_key)
				if not res then
					break
				end
				local tab = json.decode(res)
				if tab["error"] then
					print(res)
					break
				end
				local balance, name, symbol, price, mk, decimals, token_address
				local token_tab = tab["tokens"]
				if not token_tab then
					break
				end
				for _, token_tbl in pairs(token_tab) do
					for general, info in pairs(token_tbl) do
						if general == "balance" then balance = info
						elseif general == "tokenInfo" then
							for data, value in pairs(info) do
								if data == "name" then
									name = value
								elseif data == "address" then
									token_address = value
								elseif data == "symbol" then
									symbol = value
								elseif data == "decimals" then
									decimals = tonumber(value)
								elseif data == "price" and type(value) == "table" then
									for data_price, value_price in pairs(value) do
										if data_price == "rate" then
											price = value_price
										elseif data_price == "marketCapUsd" then
											mk = value_price
										end
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
						local amount
						-- If there is a significant value of a token in the wallet, then probably listed
						if wallet_value > 10000 then
							if wallet_value > 100000 then
								amount = 100
							else
								amount = 10
							end
							-- Checks if it was a huge amount of tokens in the previous checks
							local stored_tokens = redis:smembers(exchange)
							local searched = false
							for _, tokens_data in pairs(stored_tokens) do
								local symbol_, name_, balance_, price_, amount_ = string.match(tokens_data, "^(.*):(.*):(.*):(.*):(.*)")
								if symbol_ == symbol and name_ == name then
									-- First filter: compare old and new token quantities in terms of 10k or 100k usd
									if tonumber(amount_) >= tonumber(amount) then
										searched = true
										amount = amount_
									end
									-- Intermediate filter: do not send notification when the difference of new vs old token value is small (< 20%)
									local wallet_value_ = tonumber(balance_) * tonumber(price_)
									if wallet_value * 0.8 < wallet_value_ then
										searched = true
									end
									redis:srem(exchange , tokens_data)
									redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price .. ":" .. amount)
								end
							end
							if not searched then
								local new_tx = true
								-- Let's see if the tokens were transferred recently
								local res_etherscan = https.request(etherscan_endpoint:format(token_address, eth_address))
								if res_etherscan then
									local tab_etherscan = json.decode(res_etherscan)
									if tab_etherscan["status"] == "1" then
										print(name)
										local timestamp = tab_etherscan["result"][1]["timeStamp"]
										local time = os.time(os.date("!*t"))
										if time - tonumber(timestamp) > 85000 then
											redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price .. ":" .. amount)
											print(time , timestamp)
											new_tx = false
										end
									else
										print(res_etherscan)
									end
								end		
								-- Avoid sending many messages when a exchange has been recently added
								if not new_exchange and new_tx then
									local text = {}
									text[1] = "🚀 *New tokens detected in a selected exchange wallet!*\n"
									text[2] = "*• Token:* " .. name .. " (" .. symbol .. ")\n"
									text[3] = "*• Address:* " .. token_address .. "\n"
									text[4] = "*• Exchange:* " .. exchange .. "\n"
									text[5] = "*• Wallet:* `" .. eth_address .. "`\n"
									text[6] = "*• Balance:* " .. round(balance, 0) .. " tokens\n"
									text[7] = "*• Token price:* $" .. round(price, 2) .. "\n"
									text[8] = "*• Token value in wallet:* $" .. round(wallet_value, 2) .. "\n\n"
									text[9] = "[Ethplorer](https://ethplorer.io/address/" .. eth_address .. ") - [Etherscan](https://etherscan.io/token/" .. token_address .. "?a=" .. eth_address .. ") - [Etherchain](https://www.etherchain.org/account/" .. eth_address .. ") - [CoinMarketCap](https://coinmarketcap.com/search/?q=" .. symbol .. ") - [CoinCheckup](https://coincheckup.com/)"
									text = table.concat(text)
									print("Attention: new token in " .. exchange, symbol)
									https.request("https://api.telegram.org/bot" .. telegram_token .. "/sendMessage?chat_id=" .. testing_id .. "&text=" .. urlencode(text) .. "&parse_mode=Markdown&disable_web_page_preview=true")
								else
									print("New coin in a new exchange, skipping...")
								end
							end
							redis:sadd(exchange, symbol .. ":" .. name .. ":" .. balance .. ":" .. price .. ":" .. amount)
						end
					end
					tokens = tokens + 1
				end
			end
		end
		print(os.date(), "------------ Completed: " .. tokens .. " tokens scanned --------------")
		last_time = os.time()
	end
end
