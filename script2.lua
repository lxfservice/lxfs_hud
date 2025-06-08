local ESX = exports.es_extended:getSharedObject()

ESX.RegisterServerCallback('lxfs_hud:getBankMoney', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
    local bankMoney = 0
    
    for _, account in pairs(xPlayer.getAccounts()) do
        if account.name == 'bank' then
            bankMoney = account.money
            break
        end
    end

    cb(bankMoney)
        else
            print("Error while loading xPlayer")
        end
end)
