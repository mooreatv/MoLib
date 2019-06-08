for %%i in (_retail_ _classic_beta_) do (
    for %%a in (WhoTracker DynamicBoxer Camera) do (
        echo Installing for %%i and %%a
        xcopy /i /y *.lua "C:\Program Files (x86)\World of Warcraft\%%i\Interface\Addons\%%a\MoLib\"
    )
)
