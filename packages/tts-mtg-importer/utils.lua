local M = {}

--- This function converts a list of the following structure:
--- [{}, {}, {}, {}, {}]
--- Into batches of the given size with the following example structure (batch size of 3):
--- [[{}, {}, {}], [{}, {}]]
--- The itemMapper parameter can also be used to map an item's structure before batching.
function M.batchFromList(list, batchSize, itemMapper)
    if batchSize == nil then batchSize = 1 end
    if itemMapper == nil then
        itemMapper = function(item) return item end
    end
    local batches = {}
    local currentBatch = {}
    for i, item in ipairs(list) do
        if #currentBatch == batchSize then
            -- this batch is full, move onto the next batch
            table.insert(batches, currentBatch)
            currentBatch = {}
        end

        if #currentBatch < batchSize then
            -- insert the mapped item into the current batch as long as there's room
            table.insert(currentBatch, itemMapper(item))
        end
    end
    -- insert final batch
    table.insert(batches, currentBatch)
    return batches
end

--- Converts a URI (usually a Scryfall image link) to a specific quality and removes unneeded query data.
function M.truncateURI(uri, quality, suffix)
    if quality == 'png' then
        uri = uri:gsub('.jpg', '.png')
    end
    return uri:gsub('%?.*', ''):gsub('normal', quality) .. suffix
end

return M