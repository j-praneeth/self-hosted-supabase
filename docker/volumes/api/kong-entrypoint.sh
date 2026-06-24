#!/bin/bash

if [ -n "$SUPABASE_SECRET_KEY" ] && [ -n "$SUPABASE_PUBLISHABLE_KEY" ]; then

export LUA_AUTH_EXPR="\$((headers.authorization ~= nil and headers.authorization:sub(1, 10) ~= 'Bearer sb_' and headers.authorization) or (headers.apikey == '$SUPABASE_SECRET_KEY' and 'Bearer $SERVICE_ROLE_KEY_ASYMMETRIC') or (headers.apikey == '$SUPABASE_PUBLISHABLE_KEY' and 'Bearer $ANON_KEY_ASYMMETRIC') or headers.apikey)"

export LUA_RT_WS_EXPR="\$((query_params.apikey == '$SUPABASE_SECRET_KEY' and '$SERVICE_ROLE_KEY_ASYMMETRIC') or (query_params.apikey == '$SUPABASE_PUBLISHABLE_KEY' and '$ANON_KEY_ASYMMETRIC') or query_params.apikey)"

else

export LUA_AUTH_EXPR="\$((headers.authorization ~= nil and headers.authorization:sub(1, 10) ~= 'Bearer sb_' and headers.authorization) or headers.apikey)"

export LUA_RT_WS_EXPR="\$(query_params.apikey)"

fi

TMP_KONG=/tmp/kong.generated.yml

awk '
{
result = ""
rest = $0

while (match(rest, /\$[A-Za-z_][A-Za-z_0-9]*/)) {
varname = substr(rest, RSTART + 1, RLENGTH - 1)

if (varname in ENVIRON)
result = result substr(rest,1,RSTART-1) ENVIRON[varname]
else
result = result substr(rest,1,RSTART+RLENGTH-1)

rest = substr(rest,RSTART+RLENGTH)
}

print result rest
}
' "$KONG_DECLARATIVE_CONFIG" > "$TMP_KONG"

sed -i '/^[[:space:]]- key:[[:space:]]$/d' "$TMP_KONG"

export KONG_DECLARATIVE_CONFIG="$TMP_KONG"

exec /entrypoint.sh kong docker-start
