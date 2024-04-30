using JSPEC
using Test

@testset "JSPEC.jl" begin
    # Write your tests here.
    # CreateDataSet
    newdt = CreateDataSet("XRTTest","Swift-XRT")
    @test newdt["Instrument"] == "Swift.XRT" 
    #
    # ImportData
    frmf = joinpath("testdata","xrtwt.rmf")
    farff = joinpath("testdata","xrtwt.arf")
    fsrc = joinpath("testdata","xrtwtsource.pi")
    fbck = joinpath("testdata","xrtwtback.pi")
    ImportData(newdt, rmffile=frmf, arffile=farf, srcfile=fsrc, bckfile=fbck)
    @test newdt["ImportedData"] == true
    #
end
