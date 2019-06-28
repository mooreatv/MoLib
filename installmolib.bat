for %%i in (_retail_ _classic_ _classic_beta_ _ptr_) do (
    for %%a in (WhoTracker DynamicBoxer Camera RandomGenerator) do (
        echo Installing for %%i and %%a
        xcopy /i /y *.lua "C:\Program Files (x86)\World of Warcraft\%%i\Interface\Addons\%%a\MoLib\"
    )
)
