module JSPEC

using CairoMakie
using DataFrames
using FITSIO
using LaTeXStrings
using LinearAlgebra



export CreateDataSet
export GetKnownInstruments
export ImportData


KnownInstruments = ["Swift-XRT", "Swift-BAT", "SVOM-MXT", "Other"]




"""
    CreateDataSet(Name::String, Instrument::String; verbose=true)::Dict

Create JSPECDataSent entry. 'Name' is the arbitrary name of the dataset one may choose and 'Instrument' is one of supperted instrument by the package.


# Examples
```jldoctest
newdataset = CreateDataSet("XRTTest","Swift-XRT")

# output

Dict{Any, Any} with 3 entries:
  "Name"       => "XRTTest"
  "Instrument" => "Swift-XRT"
  "Created"    => true
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



"""
    ImportData(ds::Dict; rmffile::String="", arffile::String="", srcfile::String="", bckfile::String="", verbose=true)

Import data from "multi-channel" instruments (e.g., Swift-XRT) as FITS files and add fields to the JSPECDataSet dictionary. 'ds' is the JSPEC data set dictionary, 'rmfile' is the RMF response matrix, 'arffile' the effective area matrix, 'srcfile' the counts (or rates) for the source, and 'bckfile' the counts or rates for the background.

# Examples

```julia
fnrmf = joinpath("data","wt.rmf")
fnarf = joinpath("data","wt.arf")
fnpisrc = joinpath("data","wtsource.pi")
fnpibck = joinpath("data","tback.pi");

ImportData(newdataset, rmffile=fnrmf,arffile=fnarf,srcfile=fnpisrc,bckfile=fnpibck)
```
"""
function ImportData(ds::Dict; rmffile::String="", arffile::String="", srcfile::String="", bckfile::String="", verbose=true)
    if haskey(ds,"Created") && !ds["Created"]
        if verbose
            println("Warning! Dataset not created yet.")
        end
    elseif ds["Instrument"] == "Other"
        if verbose
            println("Warning! Use ImportOtherData instead.")
        end
    elseif uppercase(ds["Instrument"]) ∉ [uppercase(i) for i in JSPEC.KnownInstruments]
        if verbose
            println("Warning! Unknown intrument.")
        end
    else
        if rmffile != ""
            rmf = FITS(rmffile)
            if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
                ds["RMF"] = DataFrame(rmf[3])
                ds["Channels"] = DataFrame(rmf[2])
                ds["ChanNumber"] = ds["Channels"][!,"CHANNEL"]
            elseif uppercase(ds["Instrument"]) == uppercase("Swift-BAT")
                ds["RMF"] = DataFrame(rmf[2])
                ds["Channels"] = DataFrame(rmf[3])
                ds["ChanNumber"] = ds["Channels"][!,"CHANNEL"]            
            elseif uppercase(ds["Instrument"]) == uppercase("SVOM-MXT")
                ds["RMF"] = DataFrame(rmf[2])
                ds["Channels"] = DataFrame(rmf[3])
                ds["ChanNumber"] = ds["Channels"][!,"CHANNEL"]
            end
            #
            ds["Channels"][!,"E"] = (ds["Channels"][!,"E_MIN"] + ds["Channels"][!,"E_MAX"])/2.
            #
            en = (ds["RMF"][!,"ENERG_LO"] .+ ds["RMF"][!,"ENERG_HI"]) ./ 2
            de = (ds["RMF"][!,"ENERG_HI"] .- ds["RMF"][!,"ENERG_LO"])
            ds["Energy"] = DataFrame(E=en,ΔE=de, MinE=ds["RMF"][!,"ENERG_LO"], MaxE=ds["RMF"][!,"ENERG_HI"])
        end
        if arffile != ""
            arf = FITS(arffile)
            if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
                ds["ARF"] = DataFrame(arf[2])
            elseif uppercase(ds["Instrument"]) == uppercase("SVOM-MXT")
                ds["ARF"] = DataFrame(arf[2])
            end
        end
        if srcfile != ""
            pisrc = FITS(srcfile)
            if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
                ds["SrcCnt"] = DataFrame(pisrc[2])
                ds["InputSrcData"] = ds["SrcCnt"][!,"COUNTS"]
            elseif uppercase(ds["Instrument"]) == uppercase("Swift-BAT")
                ds["SrcRate"] = DataFrame(pisrc[2])
                ds["InputSrcRate"] = ds["SrcRate"][!,"RATE"]
                ds["InputSrcRateErr"] = ds["SrcRate"][!,"STAT_ERR"]
                ds["InputSrcRateSysErr"] = ds["SrcRate"][!,"SYS_ERR"]            
            elseif uppercase(ds["Instrument"]) == uppercase("SVOM-MXT")
                ds["SrcCnt"] = DataFrame(pisrc[2])
                ds["InputSrcData"] = ds["SrcCnt"][!,"COUNTS"]
            end
            heasrc = read_header(pisrc[2])
            ds["SrcExpTime"] = heasrc["EXPOSURE"]
            ds["SrcBackScal"] = heasrc["BACKSCAL"]
        end
        if bckfile != ""
            pibck = FITS(bckfile)
            if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
                ds["BckCnt"] = DataFrame(pibck[2])
                ds["InputBckData"] = ds["BckCnt"][!,"COUNTS"]
            elseif uppercase(ds["Instrument"]) == uppercase("SVOM-MXT")
                ds["BckCnt"] = DataFrame(pibck[2])
                ds["InputBckData"] = ds["BckCnt"][!,"COUNTS"]
            end
            #
            heabck = read_header(pibck[2])
            ds["BckExpTime"] = heabck["EXPOSURE"]
            ds["BckBackScal"] = heabck["BACKSCAL"]
        else
            ds["BckExpTime"] = 1.
            ds["BckBackScal"] = 1.
        end
        ds["BackScaleRatio"] = ds["SrcBackScal"]/ds["BckBackScal"] 
        ds["ExposureRatio"] = ds["SrcExpTime"]/ds["BckExpTime"]
        #
        if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
            ds["InputBckDataCorr"] = ds["InputBckData"]*ds["BackScaleRatio"]*ds["ExposureRatio"]
            ds["InputData"] = ds["InputSrcData"] .- ds["InputBckDataCorr"]
            ds["InputDataErr"] = sqrt.(ds["InputSrcData"] .+ ds["InputBckDataCorr"])
        elseif uppercase(ds["Instrument"]) == uppercase("Swift-BAT")
            ds["InputData"] = ds["InputSrcRate"]
            ds["InputDataErr"] = ds["InputSrcRateErr"]
        elseif uppercase(ds["Instrument"]) == uppercase("SVOM-MXT")
            ds["InputBckDataCorr"] = ds["InputBckData"]*ds["BackScaleRatio"]*ds["ExposureRatio"]
            ds["InputData"] = ds["InputSrcData"] .- ds["InputBckDataCorr"]
            ds["InputDataErr"] = sqrt.(ds["InputSrcData"] .+ ds["InputBckDataCorr"])
        end
        ds["ImportedData"] = true
    end
end



end