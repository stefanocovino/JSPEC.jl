module JSPEC

using CairoMakie
using DataFrames
using FITSIO
using LaTeXStrings
using LinearAlgebra



export CreateDataSet
export GetKnownInstruments
export GenResponseMatrix
export IgnoreChannels
export ImportData
export ImportOtherData
export PlotRaw
export PlotRebinned
export RebinAncillaryData
export RebinData



KnownInstruments = ["Swift-XRT", "Swift-BAT", "SVOM-MXT", "Other"]




"""
    CreateDataSet(Name::String, Instrument::String; verbose=true)::Dict

Create a JSPECDataSent entry. 

#Arguments

- `Name` is the arbitrary name of the dataset.
- `Instrument` is one of supperted instrument by the package. 
- `verbose` enables warning messages.


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
    FindRebinSchema(x,ey;minSN=5)::AbstractVector{Real}

Compute the rebin schema to guarantee that the S/N is at least `minSN` in each bin (or channel). 

# Arguments

- `x` input array.
- `ex` uncertainties.

# Examples
```jldoctest

x = [1.,2.,3.,4.,]
ex = [0.1,0.5,0.6,0.05]

JSPEC.FindRebinSchema(x,ex)

# output

3-element Vector{Real}:
 1
 3
 4

```
"""
function FindRebinSchema(x::AbstractVector{Float64},ex::AbstractVector{Float64};minSN=5)::AbstractVector{Real}
    sbin = []
    i = 1
    while i <= length(x)
        for l in i:length(x)
            c = sum(x[i:l])
            b = sqrt(sum(ex[i:l].^2))
            if abs(c)/b >= minSN || l == length(x)
                push!(sbin,l)
                i = l+1
                break
            end
        end
    end
    return sbin
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
    GenRebin(x,rebs)::AbstractVector{Real}

Rebin input data following a given rebin schema.

# Arguments

- `x` input array.
- `rebs` array with rebin schema.


# Examples
```jldoctest

x = [1.,2.,3.,4.,]
rbs = [1,3,4]

JSPEC.GenRebin(x,rbs)

# output

3-element Vector{Real}:
 1.0
 2.5
 4.0

```
"""
function GenRebin(x,rebs)::AbstractVector{Real}
    newa = zeros(Real,length(rebs))
    old = 1
    for l in enumerate(rebs)
        newa[l[1]] = sum(x[old:l[2]])/Float64(length(x[old:l[2]]))
        old = l[2]+1
    end
    return newa
end



"""
    GenResponseMatrix(ds::Dict; verbose=true)

Generate a rebinned response matrix following the rebin schema identified for input data.

# Arguments

- `ds` JSPEC data set dictionary.


# Examples
```julia

GenResponseMatrix(newdataset)

```
"""
function GenResponseMatrix(ds::Dict; verbose=true)
    if "RebinnedData" in keys(ds) && ds["RebinnedData"] && "RebinnedAncillaryData" in keys(ds) && ds["RebinnedAncillaryData"]
        if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
            matx = ds["MaskedRMF"][!,"MATRIX"] .* ds["ARF"][!,"SPECRESP"]
        elseif uppercase(ds["Instrument"]) == uppercase("Swift-BAT")
            matx = ds["MaskedRMF"][!,"MATRIX"]
        end
        #
        vt = zeros(length(ds["RebinSchema"]),length(matx))
        for i in 1:size(vt)[2]
            vt[:,i] = JSPEC.GenRebin(matx[i],ds["RebinSchema"])
        end
        ds["RebinnedMaskedRMF"] = vt
        ds["RebinnedResponseMatrix"] = true
    else
        if verbose
            println("Warning! Data not fully rebinned yet!")
        end
    end
end







"""
    IgnoreChannels(ds:Dict, chns; verbose=true)

Ignore channels in the input data. 

# Arguments

- `ds` JSPEC data set dictionary.
- `chns` vector of channels to be ignored, 
    e.g. [0,1,2,3] or even [0:4, 1000:1023]. Pay attention that channel numbering starts at 0. 
- `verbose` enables warning messages.


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
        ds["IgnoredChannels"] = false
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

Import data from "multi-channel" instruments (e.g., Swift-XRT). 

# Arguments

- `ds`` JSPEC data set dictionary.
- `rmfile`` RMF response matrix.
- `arffile` effective area matrix.
- `srcfile` source counts (or rate).
- `bckfile` background counts (or rate). 
- `verbose` enables warning messages.


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

Import data already in physical units. 

# Arguments

- `ds` JSPC dictionary.
- `energy` input energy (KeV).
- `phflux` photon flux density (``photons~cm{^-2}~s{^-1}~KeV{^-1})``. 
- `ephflux` photon flux density uncertainty. 
- `bandwidth` band width (KeV). 
- `verbose? enable warning message.

Bandwidth is needed only in case photon flux (``photons~cm{^-2}~s{^-1})``, rather then photon flux
density, is provided.


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

Draw a plot of the raw input data. 

# Arguments

- `ds` JSPEC data set dictionary.
- `xlbl` x-axis label.
- `ylbl` y-axis label.
- `tlbl` plot title.
- `verbose` enables warning messages.

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




"""
    PlotRebinned(ds:Dict; xlbl="Channels", ylbl="Counts", tlbl=ds.Name, verbose=true)::Figure

Draw a plot of the rebinned input data. 

# Arguments

- `ds` JSPEC data set dictionary.
- `xlbl` x-axis label.
- `ylbl` y-axis label.
- `tlbl` plot title.
- `verbose` enables warning messages.


# Examples
```julia
figreb = PlotRebinned(newdataset)
```
"""
function PlotRebinned(ds::Dict; xlbl="Channels", ylbl=L"Counts ch$^{-1}$ s$^{-1}$", tlbl=ds["Name"],verbose=true)::Figure
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
    if uppercase(ds["Instrument"]) == uppercase("Other")
        scatter!(ds["Energy"],ds["PhFlux"],color=(:orange,0.2))
        errorbars!(ds["Energy"],ds["PhFlux"],ds["PhFluxErr"],color=(:orange,0.2))
    elseif "RebinnedData" in keys(ds) && ds["RebinnedData"] && "RebinnedAncillaryData" in keys(ds) && ds["RebinnedAncillaryData"]
      scatter!(ds["RebinnedMaskedChannel"],ds["RebinnedMaskedInputData"],color=(:orange,0.2))
      errorbars!(ds["RebinnedMaskedChannel"],ds["RebinnedMaskedInputData"],ds["RebinnedMaskedInputDataErr"],color=(:orange,0.2))
    else
      if verbose
        println("Warning! Data not fully rebinned yet.")
      end
    end
    #
    return fig
end



"""
    RebinAncillaryData(ds::Dict; verbose=true)

Rebin ancillary data (channels, channel energy, etc.) with the rebin schema identified for input data.

# Arguments

- `ds` JSPEC data set disctionary.
- `verbose` enables warning messages.


# Examples
```julia

RebinAncilaryData(newdataset)

```
"""
function RebinAncillaryData(ds::Dict; verbose=true)
    if "RebinnedData" in keys(ds) && !ds["RebinnedData"]
        if verbose
            println("Warning! Channels not rebinned yet.")
        end
        ds["RebinnedAncillaryData"] = false
    else
        ds["RebinnedMaskedEnergy"] = JSPEC.GenRebin(ds["MaskedChannels"][!,"E"],ds["RebinSchema"])
        ds["RebinnedMaskedChannel"] = JSPEC.GenRebin(ds["MaskedChannels"][!,"CHANNEL"],ds["RebinSchema"]) 
        ds["RebinnedAncillaryData"] = true
    end
end



"""
    RebinData(ds::Dict;minSN=5,verbose=true)

Rebin input data with a mininum S/N per bin. 

# Arguments

- `ds` JSPEC data set disctionary.
- `minSN` minimum S/N per bin.
- `verbose` enables warning messages.


# Examples
```julia

RebinData(newdataset)

```
"""
function RebinData(ds::Dict;minSN=5,verbose=true)
    if !ds["IgnoredChannels"]
        if verbose
            println("Warning! Channels not ignored yet.")
        end
        ds["RebinnedData"] = false
    else
        ds["RebinSchema"] = JSPEC.FindRebinSchema(ds["MaskedInputData"],ds["MaskedInputDataErr"],minSN=minSN)
        ncts = zeros(Real,length(ds["RebinSchema"]))
        encts = zeros(Real,length(ds["RebinSchema"]))
        old = 1
        for l in enumerate(ds["RebinSchema"])
            c = sum(ds["MaskedInputData"][old:l[2]])
            b = sqrt(sum(ds["MaskedInputDataErr"][old:l[2]].^2))
            ncts[l[1]] = c/length(ds["MaskedInputData"][old:l[2]])
            encts[l[1]] = b/length(ds["MaskedInputDataErr"][old:l[2]])
            old = l[2]+1
        end
        if uppercase(ds["Instrument"]) == uppercase("Swift-XRT")
            ds["RebinnedMaskedInputData"] = ncts/ds["SrcExpTime"]
            ds["RebinnedMaskedInputDataErr"] = encts/ds["SrcExpTime"]
        elseif uppercase(ds["Instrument"]) == uppercase("Swift-BAT")
            ds["RebinnedMaskedInputData"] = ncts
            ds["RebinnedMaskedInputDataErr"] = encts
        end
        #
        ds["RebinnedData"] = true
    end
end






end
