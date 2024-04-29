# JSPEC

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://stefanocovino.github.io/JSPEC.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://stefanocovino.github.io/JSPEC.jl/dev/)
[![Build Status](https://github.com/stefanocovino/JSPEC.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/stefanocovino/JSPEC.jl/actions/workflows/CI.yml?query=branch%3Amain)

This is a package to allow to read and analyse spectra obtained from multi-channel instruments (e.g., Swift-XRT) with data from any other source (e.g. optical/NIR observations). Altough several features are in common there is no attempt to mimic the full funtionalities offered by [XSPEC](https://heasarc.gsfc.nasa.gov/xanadu/xspec/). At present, only fits with a Gaussian likelihod are implemented. Fits in a full Poissonian regime will be included in a future (or never...). 


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

The purpose of the package is to provide tools to mode data from multi-channel instruments togeter, if needed, with data from any other surce. The package compute the needed response matrces that can then used for cretig models, carry out fits, etc.

No attept has been tried, on purpose, to mimic the simplified XSPEC syntax to create models, etc.

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