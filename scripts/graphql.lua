-- Module instantiation
local cjson = require "cjson"
local cjson2 = cjson.new()
local cjson_safe = require "cjson.safe"

-- to hold a list of queries and variables for them
requests = nil
-- to hold the indexes into the queries and their variables.
indexes = nil

-- Initialize the pseudo random number generator
-- Resource: http://lua-users.org/wiki/MathLibraryTutorial
math.randomseed(os.time())
math.random(); math.random(); math.random()

-- Shuffle array (in place)
function shuffle(items)
  local j, k
  local n = #items

  if n > 1 then
    for i = 1, n do
      j, k = math.random(n), math.random(n)
      items[j], items[k] = items[k], items[j]
    end
  end
end

-- https://riptutorial.com/lua/example/20315/lua-pattern-matching
function split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end

-- Load GraphQL requests from the file
function load_json(file)
  local content

  -- Check if the file exists
  local f=io.open(file,"r")
  if f ~= nil then
    content = f:read("*all")
    io.close(f)
  else
    -- Return the empty array
    print("Unable to find or open json file: "..file)
    os.exit()
  end

  -- Translate Lua values from JSON
  return cjson.decode(content)
end

-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.
function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

-- Get options
-- -d <path>, --data <path>, this is the json file to read requests
-- -i <num>, --index <num>, index to request in the file to benchmark
init = function(args)
  -- get and print out options
  local opts = getopt( args, "di" )
  -- for k, v in pairs(opts) do
  --   print("Argument: " .. k .. "=" .. v )
  -- end
  -- pars indexes
  local idxs = {}
  local idxstr = "1"
  if opts["i"] ~= nil then
    idxstr = opts["i"]
  elseif opts["index"] ~= nil then
    idxstr = opts["index"]
  end
  local idxstrs = split(idxstr, ",")
  idx_max = 0
  for _, v in ipairs(idxstrs) do
    local idx = tonumber(v)
    if (idx ~= nil and idx > 0) then
      if idx > idx_max then
        idx_max = idx
      end
      local i = {}
      i.query = idx
      i.variables = 1
      table.insert(idxs, i)
    end
  end
  if idx_max == 0 then
    print("No valid index found: "..idxstr)
    os.exit()
  end
  -- Load URL requests from file
  local data = nil
  if opts["d"] ~= nil then
    data = opts["d"]
  elseif opts["data"] ~= nil then
    data = opts["data"]
  end
  if data ~= nil then
    reqs = load_json(data)
    -- Verify a query for all indexes by comparing total queries to max index 
    if #reqs.queries < idx_max then
      print("No GraphQL query found for index: " .. idx_max)
      os.exit()
    end
    print("Found " .. #reqs.queries .. " multiple GraphQL queries.")
  else
    print("Please include data file via -f <path> or --file=<path> options to load GraphQL queries.")
    os.exit()
  end
  requests = reqs
  indexes = idxs
end

flag = true
counter = 1
request = function()
  -- Get the next query and variable
  local query = requests.queries[indexes[counter].query]
  local variables = nil
  if query.variables ~= nil then
    if type(query.variables) == 'table' then
      if #query.variables > 0 then
        variables = query.variables[indexes[counter].variables]
        indexes[counter].variables = indexes[counter].variables + 1
        if indexes[counter].variables > #query.variables then
          indexes[counter].variables = 1
        end
      end
    elseif type(query.variables) == 'string' then
      variables = requests.lists[query.variables][indexes[counter].variables]
      indexes[counter].variables = indexes[counter].variables + 1
      if indexes[counter].variables > #requests.lists[query.variables] then
        indexes[counter].variables = 1
      end
    end
  end

  -- print out first round of graphs
  if flag then
    print("BENCH:" .. query.tag .. "\n" .. query.graph)
  end

  -- Increment queries counter
  counter = counter + 1
  -- If the counter is longer than the requests array length then reset
  -- and nolonger print query being benchmarked
  if counter > #indexes then
    counter = 1
    flag = false
  end
  body = nil
  if variables ~= nil then
    body = "{\"query\":\"query " .. query.graph .. "\",\"variables\":" .. variables .. "}"
  else
    body = "{\"query\":\"query {" .. query.graph .. "}\"}"
  end
  -- print("Body: "..body)
  -- Return the request object with the current headers and body
  return wrk.format("POST", nil, requests.headers, body)
end

response_error_total = 0
-- how to alert wrk2 that graphql sent back
-- an error that only listed in the body
response = function(status, headers, body)
  if status == 200 then
    content = cjson.decode(body)
    if content == nil then
      print("ERROR: No JSON found in the response.")
      response_error_total = response_error_total + 1
    elseif content["errors"] ~= nil then
      -- assuming at least one error and that it always comes back as an array.
      print("ERROR: "..content.errors[1].message)
      response_error_total = response_error_total + 1
    end
  else
    print("ERROR: non-2xx STATUS: "..status..", BODY: "..body)
  end
end
