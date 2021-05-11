for %%i in (_retail_ _classic_ _beta_ _classic_ptr_ _ptr_) do (
    for %%a in (NeatMinimap Mama DynamicBoxer PixelPerfectAlign BetterVendorPrice AuctionDB) do (
        echo Installing for %%i and %%a
        xcopy /i /y *.lua "C:\Program Files (x86)\World of Warcraft\%%i\Interface\Addons\%%a\MoLib\"
    )
)
