module CxxROOT

using Cxx

function __init__()
    addHeaderDir("/Users/kfischer/Projects/root/core/base/inc",kind=C_System)
    addHeaderDir("/Users/kfischer/Projects/root/core/meta/inc",kind=C_System)
    addHeaderDir("/Users/kfischer/Projects/root/core/metautils/inc",kind=C_System)
    addHeaderDir("/Users/kfischer/Projects/root/core/meta/src",kind=C_System)
    addHeaderDir("/Users/kfischer/Projects/root/obj/include",kind=C_System)
    Libdl.dlopen("/Users/kfischer/Projects/root/obj/lib/libCore.so", Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    Libdl.dlopen("/Users/kfischer/Projects/root/obj/lib/libCling.so", Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    cxx"""
        #include "TROOT.h"
        #include "TInterpreter.h"
        #include "TSystem.h"
        #include "TClass.h"
        #include "TApplication.h"
        #include "TPluginManager.h"
    """
    cxxinclude(joinpath(dirname(@__FILE__),"TCxx.cxx"))
end
__init__()

const globalMapFile = Dict{UTF8String,UTF8String}()

macro gDebug(level,expr)
    quote
        if icxx"gDebug;" > $level
            $expr
        end
    end
end

function ReadRootmap(file; mapfile = globalMapFile)
    decls = IOBuffer()
    open(file,"r") do f
        l = eachline(f)
        it = start(l)
        local libname
        while !done(l,it)
            line, it = next(l, it)
            line = rstrip(line)
            if startswith(line,"{ decls }")
                while !done(l,it)
                    line, it = next(l,it)
                    line[1] == '[' && break
                    write(decls, line)
                end
            end
            c = line[1]
            if c == '['
                idx = findfirst(line,']')
                idx == 0 && continue
                libname = line[2:idx-1]
                libname = lstrip(libname,' ')
            else
                keyLen = c == 'c' ?  6 :
                         c == 'n' ? 10 :
                         c == 't' ?  8 :
                         c == 'h' ?  7 :
                         c == 'e' ?  5 :
                            continue
                keyname = line[1+keyLen:end]
                if haskey(mapfile, keyname)
                    if libname != mapfile[keyname]
                        if c == 'n'
                            @gDebug 3 info("namespace $keyname found in $(libname)"*
                                           "is already in $(mapfile[keyname])")
                        elseif c == 'h'
                            mapfile[keyname] = string(libname,mapfile[keyname])
                        else
                            warn("$line found in $libname is already in $(mapfile[keyname])")
                        end
                    end
                else
                    mapfile[keyname] = libname
                end
            end
        end
    end
end

function LoadLibraryMap()
    paths = unique(split(bytestring(icxx"gSystem->GetDynamicPath();"),
        OS_NAME == :WIINT ? ';' : ':',keep = false))
    for path in paths
        isdir(path) || continue
        for entry in readdir(path)
            if endswith(entry, "rootmap")
                if entry == ".rootmap"
                    continue
                end
                ReadRootmap(joinpath(path,entry))
            end
        end
    end
end

GetClassSharedLibs(class; map = globalMapFile) = globalMapFile[class]

@cxxm "const char *TCxx::GetClassSharedLibs(const char *cls)" begin
    pointer(GetClassSharedLibs(bytestring(cls)))
end

@cxxm "Int_t TCxx::AutoLoad(const char *classname, Bool_t knowDictNotLoaded)" begin
    for lib in split(GetClassSharedLibs(bytestring(classname)),' '; keep=false)
        Libdl.dlopen(joinpath("/Users/kfischer/Projects/root/obj/lib/",lib), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    end
    0
end

function unsafe_load_array(strings::Ptr{Ptr{UInt8}})
    i = 1
    ret = UTF8String[]
    while true
        p = unsafe_load(strings,i)
        if p == C_NULL
            break
        end
        push!(ret,bytestring(p))
        i += 1
    end
    ret
end

@cxxm "void TCxx::RegisterModule(const char* modulename,
                                   const char** headers,
                                   const char** includePaths,
                                   const char* payloadCode,
                                   const char* fwdDeclsCode,
                                   void (* triggerFunc)(),
                                   const TCxx::FwdDeclArgsToKeepCollection_t& fwdDeclArgsToKeep,
                                   const char** classesHeaders)" begin
    @show unsafe_load_array(includePaths)
    if payloadCode != C_NULL
        cxxparse(bytestring(payloadCode))
    end
    #=
    @show bytestring(modulename)
    @show unsafe_load_array(headers)
    
    @show payloadCode != C_NULL ? bytestring(payloadCode) : ""
    @show fwdDeclsCode != C_NULL ? bytestring(fwdDeclsCode) : ""
    @show unsafe_load_array(classesHeaders)
    =#
    nothing
end

@cxxm "Bool_t TCxx::CheckClassInfo(const char *name, Bool_t autoload, Bool_t isClassOrNamespaceOnly)" begin
    true
end

@cxxm "void TCxx::GetInterpreterTypeName(const char* name, std::string &output, Bool_t full)" begin
    icxx"$output = $name;"
    nothing
end

cxx"""
TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent) {
    Version_t version = 1;
    return new TClass(classname, version, silent);
}

void TCxx::SaveContext()
{
    return;
}

void TCxx::SaveGlobalsContext()
{
    return;
}

void TCxx::ResetGlobals()
{
    return;
}

void TCxx::UnRegisterTClassUpdate(const TClass *oldcl)
{
    return;
}

Long_t TCxx::ExecuteMacro(const char* filename, EErrorCode* error)
{
   Long_t result = TApplication::ExecuteFile(filename, (int*)error);
   return result;
}

Long_t TCxx::ProcessLineSynch(const char *line, EErrorCode *error)
{
    return ProcessLine(line, error);
}

Int_t TCxx::AutoParse(const char *cls)
{
    return AutoLoad(cls);
}

Bool_t TCxx::IsAutoParsingSuspended() const
{
    return true;
}

const char *TCxx::GetSharedLibs()
{
    return "";
}

const char *TCxx::GetSharedLibDeps(const char* lib)
{
    return 0;
}
"""
#=
@cxxm "TClass *TCxx::GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent)" begin
    icxx"new TClass($classname, $version, $silent);"
end
=#

@cxxm "Long_t TCxx::ProcessLine(const char *line, EErrorCode *error)" begin
    line = bytestring(line)
    eval(Cxx.process_cxx_string(line, false, false, :ProcessLine, 1, 1; compiler = __current_compiler__))
    0
end

@cxxm "Long_t TCxx::ExecuteMacro(const char *filename, EErrorCode *error)" begin
    filename = bytestring(filename)
    cxxinclude(filename);
    fname = basename(filename)
    fname = fname[1:(findfirst(fname,'.')-1)]
    eval(Cxx.process_cxx_string("$(fname)();", false, false, :ProcessLine, 1, 1; compiler = __current_compiler__))
    0
end

@cxxm "Int_t TCxx::LoadLibraryMap(const char *rootmapfile)" begin
    ReadRootmap(bytestring(rootmapfile))
    0
end

@cxxm "Int_t TCxx::UnloadLibraryMap(const char *library)" begin
    @show bytestring(library)
    0
end

@cxxm "Int_t TCxx::Load(const char *filenam, Bool_t system)" begin
    Libdl.dlopen(joinpath("/Users/kfischer/Projects/root/obj/lib/",bytestring(filenam)), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
    0
end

@cxxm "void TCxx::SetClassInfo(TClass *cl, Bool_t reload)" begin
    name = bytestring(icxx"$cl->GetName();");
    T = cxxparse(Cxx.instance(__current_compiler__), name, true)
    icxx"$cl->fClassInfo = (ClassInfo_t*)$(T.ptr);"
    @show T
    nothing
end

@cxxm "void TCxx::CreateListOfBaseClasses(TClass *cl) const" begin
    nothing
end

@cxxm "TCxx::DeclId_t TCxx::GetFunctionWithPrototype(ClassInfo_t *cl, const char* method, const char* proto, Bool_t objectIsConst, ROOT::EFunctionMatchMode mode)" begin
    @show bytestring(method)
    @show bytestring(proto)
    0
end

# TCollection Iteration
import Base: start, next, done
start(C::pcpp"TCollection") = icxx"$C->begin();"
next(C::pcpp"TCollection",it) = (icxx"*$it;", (icxx"$it.Next();"; it))
done(C::pcpp"TCollection",it) = icxx"$it == $C->end();"


end # module
using Cxx
