# JSPEC

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://stefanocovino.github.io/JSPEC.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://stefanocovino.github.io/JSPEC.jl/dev/)
[![Build Status](https://github.com/stefanocovino/JSPEC.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/stefanocovino/JSPEC.jl/actions/workflows/CI.yml?query=branch%3Amain)

This is a package to allow to read and analyse spectra obtained from multi-channel instruments (e.g., Swift-XRT) with data from any other source (e.g. optical/NIR observations). Altough several features are in common, no attempt to mimic the full funtionalities offered by [XSPEC](https://heasarc.gsfc.nasa.gov/xanadu/xspec/) was tried. In addition, at present, only fits with a Gaussian likelihod are implemented. Fits in a full Poissonian regime will possibly be included in a future version (or never...). 


## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/stefanocovino/JSPEC.jl.git")
```
will install this package.


### Instruments

JSPEC currently handles data from [Swift-BAT](https://science.nasa.gov/mission/swift/), [Swift-XRT](https://science.nasa.gov/mission/swift/) and [SVOM-MXT](https://www.svom.eu/en/the-svom-mission/).  


### Documentation and examples

Documentation for the package and use examples can be found [here](https://stefanocovino.github.io/JSPEC.jl/stable/).


### Similar tools

If you are interested in similar capabilities you may also check the "[SpectralFitting.jl](https://github.com/fjebaker/SpectralFitting.jl?tab=readme-ov-file)" and "[LibXSPEC_jll.jl](https://github.com/astro-group-bristol/LibXSPEC_jll.jl)".


## Getting Started

The purpose of the package is to provide tools to mode data from multi-channel instruments togeter, if needed, with data from any other surce. The package compute the needed response matrces that can then used for creating models, carry out fits, etc.

No attept has been tried, on purpose, to mimic the simplified XSPEC syntax to create models, etc. Therefore models, etc. will be coded accordind to a plain Julia syntax.

The instruments currently covered can be obtained with:

```julia
GetKnownInstruments()
```

Ad the first step is to create a new dataset. For instance, assuming we want to model 'Swift-XRT' data and data from an optical telescope, we might write:

```julia
XRTdt = CreateDataSet("XRTdata","Swift-XRT")
Optdt = CreateDataSet("Optdata","Other")
```

'XRTdt' and 'Optdt' are dictionaris that are going to include all the needed information.

Assuming we have the following 'ex.rmf', 'ex.arf', 'exsrc.pi' and 'exbck.pi' XRT files we can import them as follows:

```julia
ImportData("XRTdata", rmffile="ex.rmf", arffile="ex.arf", srcfile="exsrc.pi", bckfile="exbck.pi")
```

Optical data, but also data from any other source where a non-diagonal response matrix is not needed, should be converted to energy, in KeV, and photon flux density in photons cm$^-2£ s$^-1$ KeV$^-1$. Alternatively, data can be represented by flux but in suich a case the bandwidth, again in KeV, must be provided too.

```julia
ImportOtherData(newdataset, energy=[1.,2.,3.,4], phflux=[0.1,0.2,0.3,0.4], ephflux=[0.01,0.02,0.03,0.04])
```


