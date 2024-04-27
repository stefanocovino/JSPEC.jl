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
