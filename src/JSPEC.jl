module JSPEC

using CairoMakie
using DataFrames
using FITSIO
using LaTeXStrings
using LinearAlgebra


export GetKnownInstruments


KnownInstruments = ["Swift-XRT", "Swift-BAT", "SVOM-MXT", "Other"]


"""
    GetKnownInstruments()

Returns the instruments currently supported by the JSPEC package.


# Examples
```jldoctest
@show GetKnownInstruments()
```
"""
function GetKnownInstruments()
    return KnownInstruments
end


end
