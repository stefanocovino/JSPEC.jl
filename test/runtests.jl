using CairoMakie
using JSPEC
using Test

@testset "JSPEC.jl" begin
    # Write your tests here.
    # CreateDataSet
    newdt = CreateDataSet("XRTTest","Swift-XRT")
    @test newdt["Instrument"] == "Swift-XRT" 
    #
    # ImportData
    frmf = joinpath("testdata","xrtwt.rmf")
    farf = joinpath("testdata","xrtwt.arf")
    fsrc = joinpath("testdata","xrtwtsource.pi")
    fbck = joinpath("testdata","xrtwtback.pi")
    ImportData(newdt, rmffile=frmf, arffile=farf, srcfile=fsrc, bckfile=fbck)
    @test newdt["ImportedData"] == true
    #
    # ImportOtherData
    newodt = CreateDataSet("OptData","Other")
    ImportOtherData(newodt, [1.,2.,3.,4], [0.1,0.2,0.3,0.4], [0.01,0.02,0.03,0.04])
    @test newodt["ImportedData"] == true
    #
    # PlotRaw
    @test typeof(PlotRaw(newdt)) == Figure
    #
end
