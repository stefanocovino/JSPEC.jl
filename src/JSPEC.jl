module JSPEC

using CairoMakie
using DataFrames
using FITSIO
using LaTeXStrings
using LinearAlgebra



export CreateDataSet
export GetKnownInstruments
export IgnoreChannels
export ImportData
export ImportOtherData
export PlotRaw


KnownInstruments = ["Swift-XRT", "Swift-BAT", "SVOM-MXT", "Other"]




"""
    CreateDataSet(Name::String, Instrument::String; verbose=true)::Dict

Create JSPECDataSent entry. 'Name' is the arbitrary name of the dataset one may choose and 'Instrument' is one of supperted instrument by the package. If 'verbose' is set, it generates, if needed, a warning message if data are now properly processed.


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
    IgnoreChannels(ds:Dict, chns; verbose=true)

Ignore channels in the input data. 'ds' is the JSPEC data set dictionary, 'chns' is a vector of channels to be ignored, e.g. [0,1,2,3] or even [0:4, 1000:1023]. Please remeber that channel numebering starts with 0. If 'verbose' is set, it generates, if needed, a warning message if data are now properly processed.


# Examples
```julia
IgnoreChannels(newdataset,[0,1,2,3])
```
"""
function IgnoreChannels(ds::Dict,chns; verbose=true)
    if !ds["ImportedData"]
        if verbose
            println("Warning! Data not imported yet.")
        end
    elseif uppercase(ds["Instrument"]) == uppercase("Other")
        if verbose
            println("Warning! Data are not from a multi-channel instrument.")
        end        
    else
        mask = ones(Bool, length(ds["InputData"]))
        for e in chns
            mask[intersect(1:end, e .+ 1)] .= false
        end
        ds["MaskedInputData"] = ds["InputData"][mask]
        ds["MaskedInputDataErr"] = ds["InputDataErr"][mask]
        if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
            ds["MaskedInputSrcData"] = ds["InputSrcData"][mask]
            ds["MaskedInputBckData"] = ds["InputBckDataCorr"][mask]
        end
        #ds["MaskedChanNumber"] = ds["ChanNumber"][mask]
        #
        ds["MaskedChannels"] = copy(ds["Channels"])
        deleteat!(ds["MaskedChannels"],findall(iszero,mask))
        ds["MaskedChannels"][!,"CHANNEL"] .= 0:nrow(ds["MaskedChannels"])-1
        #
        ds["MaskedRMF"] = copy(ds["RMF"])
        for i in 1:nrow(ds["RMF"])
            ds["MaskedRMF"][i,"MATRIX"] = ds["RMF"][i,"MATRIX"][mask]
        end
        ds["IgnoredChannels"] = true
    end
end




"""
    ImportData(ds::Dict; rmffile::String="", arffile::String="", srcfile::String="", bckfile::String="", verbose=true)

Import data from "multi-channel" instruments (e.g., Swift-XRT) as FITS files and add fields to the JSPECDataSet dictionary. 'ds' is the JSPEC data set dictionary, 'rmfile' is the RMF response matrix, 'arffile' the effective area matrix, 'srcfile' the counts (or rates) for the source, and 'bckfile' the counts or rates for the background. If 'verbose' is set, it generates, if needed, a warning message if data are now properly processed.


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



"""
    ImportOtherData(ds::Dict, energy, phflux, ephflux; bandwidth=1., verbose=true)

Import data already in physical units, 'ds' is a JEPC dictionary, 'energy' is KeV, 'phflux' is the corresponding photon flux density in photons cm^-2 s^-1 KeV^-1 and 'ephflux' the uncertainty. In case it is a photon flux (photons cm^-2 s^-1) the with, in KeV, of the band, 'bandwidth' must be provided. If 'verbose' is set, it generates, if needed, a warning message if data are now properly processed.


# Examples
```julia
ImportOtherData(newdataset, [1.,2.,3.,4], [0.1,0.2,0.3,0.4], [0.01,0.02,0.03,0.04])
```
"""
function ImportOtherData(ds::Dict, energy, phflux, ephflux; bandwidth=1., verbose=true)
    if haskey(ds,"Created") && !ds["Created"]
        if verbose
            println("Warning! Dataset not created yet.")
        end
    elseif uppercase(ds["Instrument"]) == uppercase("Other")
        ds["Energy"] = energy
        ds["PhFlux"] = phflux
        ds["PhFluxErr"] = ephflux        
        ds["BandWidth"] = bandwidth
        ds["RMF"] = I
        ds["ImportedData"] = true
    else
        if verbose
            println("This function can be used only for data declared as 'Other'.")
        end
        ds["ImportedData"] = false
    end
end




"""
    PlotRaw(ds:Dict; xlbl="Channels", ylbl="Counts", tlbl=ds.Name, verbose=true)::Figure

Draw a plot of the raw input data. 'ds' is the JSPEC data set dictionary, 'xlbl' and 'ylbl' are the labels for the x and y axes, whule 'tlbl' is the plot title. If 'verbose' is set, it generates, if needed, a warning message if data are now properly processed.


# Examples
```julia
figraw = PlotRaw(newdataset)
```
"""
function PlotRaw(ds::Dict; xlbl="Channels", ylbl=L"Counts ch$^{-1}$", tlbl=ds["Name"], verbose=true)::Figure
    fig = Figure(fontsize=30)    
    #
    ax = Axis(fig[1, 1],
        spinewidth=3,
        xlabel = xlbl,
        ylabel = ylbl,
        title = tlbl,
        #yscale=log10,
        #xscale=log10,
        )
    if !ds["ImportedData"]
        if verbose
            println("Warning! Data not imported yet.")
        end
    elseif uppercase(ds["Instrument"]) == uppercase("Other")
        scatter!(ds["Energy"],ds["PhFlux"],color=(:orange,0.2))
        errorbars!(ds["Energy"],ds["PhFlux"],ds["PhFluxErr"],color=(:orange,0.2))        
    else
        scatter!(ds["ChanNumber"],ds["InputData"],color=(:orange,0.2))
        errorbars!(ds["ChanNumber"],ds["InputData"],ds["InputDataErr"],color=(:orange,0.2))
    end
    #
    return fig
end






end
