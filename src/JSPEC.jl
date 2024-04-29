module JSPEC

using CairoMakie
using DataFrames
using FITSIO
using LaTeXStrings
using LinearAlgebra



export CreateDataSet
export GetKnownInstruments


KnownInstruments = ["Swift-XRT", "Swift-BAT", "SVOM-MXT", "Other"]




"""
    CreateDataSet(Name::String, Instrument::String; verbose=true)::Dict

Create JSPECDataSent entry. 'Name' is the arbitrary name of the dataset one may choose and 'Instrument' is one of supperted instrument by the package.


# Examples
```jldoctest
newdataset = CreateDataSet("XRTTest","Swift-XRT")

# output

JSPECDataSet(
    Instrument::String = Swift-XRT, 
    Name::String = XRTTest, 
)
```
"""
function CreateDataSet(Name::String, Instrument::String; verbose=true)::Dict
    nd = Dict()
    if uppercase(Instrument) in [uppercase(i) for i in JSPEC.KnownInstruments]
        nd["Name"]=Name
        nd["Instrument"]=Instrument
        nd["Created"] = true
    else
        if verbose
            println("Warning! Unknown instrument: "*Instrument)
        end
        nd["Name"]=Name
        nd["Instrument"]=""
        nd["Created"] = false
    end
    return nd
end






"""
    GetKnownInstruments()

Returns the instruments currently supported by the JSPEC package.


# Examples
```julia
@show GetKnownInstruments()
```
"""
function GetKnownInstruments()
    return KnownInstruments
end


end
