cmake_minimum_required ( VERSION 2.8 )

project ( sendmail NONE )
include ( cmake/dist.cmake )
include ( lua )

install_lua_module ( sendmail  lua/sendmail.lua )

install_data ( README.md LICENCE.txt )
install_doc ( docs/ )
