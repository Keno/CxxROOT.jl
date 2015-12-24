#ifndef ROOT_TCxx
#define ROOT_TCxx

//////////////////////////////////////////////////////////////////////////
//                                                                      //
// TCxx                                                                 //
//                                                                      //
// A TInterpreter based on Cxx.jl.                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

#include "TInterpreter.h"
#include "TClassEdit.h"

class TCxxLookupHelper : public TClassEdit::TInterpreterLookupHelper {
public:
   TCxxLookupHelper() : TClassEdit::TInterpreterLookupHelper() {}
   virtual ~TCxxLookupHelper();

   virtual bool ExistingTypeCheck(const std::string &tname, std::string &result);
   virtual void GetPartiallyDesugaredName(std::string &nameLong) { assert(false); }
   virtual bool IsAlreadyPartiallyDesugaredName(const std::string &nondef, const std::string &nameLong) { assert(false); }
   virtual bool IsDeclaredScope(const std::string &base, bool &isInlined) { return false; }
   virtual bool GetPartiallyDesugaredNameWithScopeHandling(const std::string &tname, std::string &result);
};

TCxxLookupHelper::~TCxxLookupHelper() {}

struct TCxxClassInfo {
   clang::Decl *decl;
   clang::QualType QT;
   TCxxClassInfo(clang::Decl *D,clang::QualType QT) : decl(D), QT(QT) {}
};

struct TCxxBaseClassInfo {
   std::unique_ptr<TCxxClassInfo> child;
   std::unique_ptr<TCxxClassInfo> parent;
};

class TCxx : public TInterpreter {

private:
   TInterpreter *_fwd;

protected:
   virtual void Execute(TMethod *method, TObjArray *params, int *error = 0) { assert(false); }
   virtual Bool_t SetSuspendAutoParsing(Bool_t value) { return false; }


public:

   virtual Bool_t IsAutoParsingSuspended() const;

   TCxx() {

      auto *lookupHelper = new TCxxLookupHelper;
      TClassEdit::Init(lookupHelper);

    }   // for Dictionary
   TCxx(const char *name, const char *title = "Generic Interpreter", TInterpreter *fwd = gCling) : _fwd(fwd), TInterpreter(name,title) {

      auto *lookupHelper = new TCxxLookupHelper;
      TClassEdit::Init(lookupHelper);

   }
   virtual ~TCxx();

   virtual void     AddIncludePath(const char *path) { assert(false); }
   virtual void    *SetAutoLoadCallBack(void* /*cb*/) { return 0; }
   virtual void    *GetAutoLoadCallBack() const { return 0; }
   virtual Int_t    AutoLoad(const char *classname, Bool_t knowDictNotLoaded = kFALSE);
   virtual Int_t    AutoLoad(const std::type_info& typeinfo, Bool_t knowDictNotLoaded = kFALSE) { assert(false); }
   virtual Int_t    AutoParse(const char* cls);
   virtual void     ClearFileBusy() { assert(false); }
   virtual void     ClearStack() { assert(false); } // Delete existing temporary values
   virtual Bool_t   Declare(const char* code) { assert(false); }
   virtual void     EnableAutoLoading() { LoadLibraryMap(); }
   virtual void     EndOfLineAction() { assert(false); }
   virtual TClass  *GetClass(const std::type_info& typeinfo, Bool_t load) const { assert(false); }
   virtual Int_t    GetExitCode() const { assert(false); }
   virtual TEnv    *GetMapfile() const { return 0; }
   virtual Int_t    GetMore() const { assert(false); }
   virtual TClass  *GenerateTClass(const char *classname, Bool_t emulation, Bool_t silent = kFALSE);
   virtual TClass  *GenerateTClass(ClassInfo_t *classinfo, Bool_t silent = kFALSE);
   virtual Int_t    GenerateDictionary(const char *classes, const char *includes = 0, const char *options = 0) { assert(false); }
   virtual char    *GetPrompt() { assert(false); }
   virtual const char *GetSharedLibs();
   virtual const char *GetClassSharedLibs(const char *cls);
   virtual const char *GetSharedLibDeps(const char *lib);
   virtual const char *GetIncludePath() { assert(false); }
   virtual const char *GetSTLIncludePath() const { return ""; }
   virtual TObjArray  *GetRootMapFiles() const { assert(false); }
   virtual void     Initialize() { }
   virtual void     InspectMembers(TMemberInspector&, const void* obj, const TClass* cl, Bool_t isTransient);
   virtual Bool_t   IsLoaded(const char *filename) const { assert(false); }
   virtual Int_t    Load(const char *filenam, Bool_t system = kFALSE);
   virtual void     LoadMacro(const char *filename, EErrorCode *error = 0) { assert(false); }
   virtual Int_t    LoadLibraryMap(const char *rootmapfile = 0);
   virtual Int_t    RescanLibraryMap() { assert(false); }
   virtual Int_t    ReloadAllSharedLibraryMaps() { assert(false); }
   virtual Int_t    UnloadAllSharedLibraryMaps() { assert(false); }
   virtual Int_t    UnloadLibraryMap(const char *library);
   virtual Long_t   ProcessLine(const char *line, EErrorCode *error = 0);
   virtual Long_t   ProcessLineSynch(const char *line, EErrorCode *error = 0);
   virtual void     PrintIntro() { assert(false); }
   virtual void     RegisterModule(const char* /*modulename*/,
                                   const char** /*headers*/,
                                   const char** /*includePaths*/,
                                   const char* /*payloadCode*/,
                                   const char* /*fwdDeclsCode*/,
                                   void (* /*triggerFunc*/)(),
                                   const FwdDeclArgsToKeepCollection_t& fwdDeclArgsToKeep,
                                   const char** classesHeaders);
   virtual void     RegisterTClassUpdate(TClass *oldcl,DictFuncPtr_t dict);
   virtual void     UnRegisterTClassUpdate(const TClass *oldcl);
   virtual Int_t    SetClassSharedLibs(const char *cls, const char *libs) { assert(false); }
   virtual void     SetGetline(const char*(*getlineFunc)(const char* prompt),
                               void (*histaddFunc)(const char* line)) { assert(false); }
   virtual void     Reset() { assert(false); }
   virtual void     ResetAll() { assert(false); }
   virtual void     ResetGlobals();
   virtual void     ResetGlobalVar(void *obj) { assert(false); }
   virtual void     RewindDictionary() { assert(false); }
   virtual Int_t    DeleteGlobal(void *obj);
   virtual Int_t    DeleteVariable(const char* name) { assert(false); }
   virtual void     SaveContext();
   virtual void     SaveGlobalsContext();
   virtual void     UpdateListOfGlobals() { assert(false); }
   virtual void     UpdateListOfGlobalFunctions() { assert(false); }
   virtual void     UpdateListOfTypes() { assert(false); }
   virtual void     SetClassInfo(TClass *cl, Bool_t reload = kFALSE);
   virtual Bool_t   CheckClassInfo(const char *name, Bool_t autoload, Bool_t isClassOrNamespaceOnly = kFALSE);
   virtual Bool_t   CheckClassTemplate(const char *name) { assert(false); }
   virtual Long_t   Calc(const char *line, EErrorCode* error = 0) { assert(false); }
   virtual void     CreateListOfBaseClasses(TClass *cl) const;
   virtual void     CreateListOfDataMembers(TClass *cl) const { assert(false); }
   virtual void     CreateListOfMethods(TClass *cl) const { assert(false); }
   virtual void     CreateListOfMethodArgs(TFunction *m) const { assert(false); }
   virtual void     UpdateListOfMethods(TClass *cl) const { assert(false); }
   virtual TString  GetMangledName(TClass *cl, const char *method, const char *params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual TString  GetMangledNameWithPrototype(TClass *cl, const char *method, const char *proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) { assert(false); }
   virtual void     GetInterpreterTypeName(const char *name, std::string &output, Bool_t full = kFALSE);
   virtual void    *GetInterfaceMethod(TClass *cl, const char *method, const char *params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual void    *GetInterfaceMethodWithPrototype(TClass *cl, const char *method, const char *proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) { assert(false); }
   virtual void     Execute(const char *function, const char *params, int *error = 0) { assert(false); }
   virtual void     Execute(TObject *obj, TClass *cl, const char *method, const char *params, int *error = 0) { assert(false); }
   virtual void     Execute(TObject *obj, TClass *cl, TMethod *method, TObjArray *params, int *error = 0) { assert(false); }
   virtual void     ExecuteWithArgsAndReturn(TMethod *method, void* address, const void* args[] = 0, int /*nargs*/ = 0, void* ret= 0) const { assert(false); }
   virtual Long_t   ExecuteMacro(const char *filename, EErrorCode *error = 0);
   virtual Bool_t   IsErrorMessagesEnabled() const { assert(false); }
   virtual Bool_t   SetErrorMessages(Bool_t enable = kTRUE) { assert(false); }
   virtual Bool_t   IsProcessLineLocked() const { assert(false); }
   virtual void     SetProcessLineLock(Bool_t lock = kTRUE) { assert(false); }
   virtual const char *TypeName(const char *s) { return s; }

   // core/meta helper functions.
   virtual EReturnType MethodCallReturnType(TFunction *func) const { assert(false); }
   virtual ULong64_t GetInterpreterStateMarker() const { return 0; }

   typedef TDictionary::DeclId_t DeclId_t;
   virtual DeclId_t GetDeclId(CallFunc_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(ClassInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(DataMemberInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(FuncTempInfo_t *info) const { assert(false); }
   virtual DeclId_t GetDeclId(MethodInfo_t *info) const;
   virtual DeclId_t GetDeclId(TypedefInfo_t *info) const { assert(false); }

   virtual void SetDeclAttr(DeclId_t, const char* /* attribute */) { assert(false); }

   virtual DeclId_t GetDataMember(ClassInfo_t *cl, const char *name) const;
   virtual DeclId_t GetDataMemberAtAddr(const void *addr) const { assert(false); }
   virtual DeclId_t GetDataMemberWithValue(const void *ptrvalue) const { assert(false); }
   virtual DeclId_t GetEnum(TClass *cl, const char *name) const { assert(false); }
   virtual TEnum*   CreateEnum(void *VD, TClass *cl) const { assert(false); }
   virtual void     UpdateEnumConstants(TEnum* enumObj, TClass* cl) const { assert(false); }
   virtual void     LoadEnums(TListOfEnums& cl) const { assert(false); }
   virtual DeclId_t GetFunction(ClassInfo_t *cl, const char *funcname) { assert(false); }
   virtual DeclId_t GetFunctionWithPrototype(ClassInfo_t *cl, const char* method, const char* proto, Bool_t objectIsConst = kFALSE, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) { assert(false); }
   virtual DeclId_t GetFunctionWithValues(ClassInfo_t *cl, const char* method, const char* params, Bool_t objectIsConst = kFALSE) { assert(false); }
   virtual DeclId_t GetFunctionTemplate(ClassInfo_t *cl, const char *funcname) { assert(false); }
   virtual void     GetFunctionOverloads(ClassInfo_t *cl, const char *funcname, std::vector<DeclId_t>& res) const { assert(false); }
   virtual void     LoadFunctionTemplates(TClass* cl) const { assert(false); }

   // CallFunc interface
   virtual void   CallFunc_Delete(CallFunc_t * /* func */) const { assert(false); }
   virtual void   CallFunc_Exec(CallFunc_t * /* func */, void * /* address */) const;
   virtual void   CallFunc_Exec(CallFunc_t * /* func */, void * /* address */, TInterpreterValue& /* val */) const { assert(false); }
   virtual void   CallFunc_ExecWithReturn(CallFunc_t * /* func */, void * /* address */, void * /* ret */) const { assert(false); }
   virtual void   CallFunc_ExecWithArgsAndReturn(CallFunc_t * /* func */, void * /* address */, const void* /* args */ [] = 0, int /*nargs*/ = 0, void * /* ret */ = 0) const { assert(false); }
   virtual Long_t    CallFunc_ExecInt(CallFunc_t * /* func */, void * /* address */) const { assert(false); }
   virtual Long64_t  CallFunc_ExecInt64(CallFunc_t * /* func */, void * /* address */) const { assert(false); }
   virtual Double_t  CallFunc_ExecDouble(CallFunc_t * /* func */, void * /* address */) const { assert(false); }
   virtual CallFunc_t   *CallFunc_Factory() const;
   virtual CallFunc_t   *CallFunc_FactoryCopy(CallFunc_t * /* func */) const { assert(false); }
   virtual MethodInfo_t *CallFunc_FactoryMethod(CallFunc_t * /* func */) const { assert(false); }
   virtual void   CallFunc_IgnoreExtraArgs(CallFunc_t * /*func */, bool /*ignore*/) const;
   virtual void   CallFunc_Init(CallFunc_t * /* func */) const { assert(false); }
   virtual Bool_t CallFunc_IsValid(CallFunc_t * /* func */) const { assert(false); }
   virtual CallFuncIFacePtr_t CallFunc_IFacePtr(CallFunc_t * /* func */) const { assert(false); }
   virtual void   CallFunc_ResetArg(CallFunc_t * /* func */) const;
   virtual void   CallFunc_SetArgArray(CallFunc_t * /* func */, Long_t * /* paramArr */, Int_t /* nparam */) const { assert(false); }
   virtual void   CallFunc_SetArgs(CallFunc_t * /* func */, const char * /* param */) const { assert(false); }

   virtual void   CallFunc_SetArg(CallFunc_t * /*func */, Long_t /* param */) const;
   virtual void   CallFunc_SetArg(CallFunc_t * /*func */, ULong_t /* param */) const;
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Float_t /* param */) const;
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Double_t /* param */) const;
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, Long64_t /* param */) const;
   virtual void   CallFunc_SetArg(CallFunc_t * /* func */, ULong64_t /* param */) const;

   virtual void   CallFunc_SetFunc(CallFunc_t * /* func */, ClassInfo_t * /* info */, const char * /* method */, const char * /* params */, bool /* objectIsConst */, Long_t * /* Offset */) const;
   virtual void   CallFunc_SetFunc(CallFunc_t * /* func */, ClassInfo_t * /* info */, const char * /* method */, const char * /* params */, Long_t * /* Offset */) const { assert(false); }
   virtual void   CallFunc_SetFunc(CallFunc_t * /* func */, MethodInfo_t * /* info */) const;
   virtual void   CallFunc_SetFuncProto(CallFunc_t * /* func */, ClassInfo_t * /* info */, const char * /* method */, const char * /* proto */, Long_t * /* Offset */, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) const;
   virtual void   CallFunc_SetFuncProto(CallFunc_t * /* func */, ClassInfo_t * /* info */, const char * /* method */, const char * /* proto */, bool /* objectIsConst */, Long_t * /* Offset */, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) const { assert(false); }
   virtual void   CallFunc_SetFuncProto(CallFunc_t* func, ClassInfo_t* info, const char* method, const std::vector<TypeInfo_t*> &proto, Long_t* Offset, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) const { assert(false); }
   virtual void   CallFunc_SetFuncProto(CallFunc_t* func, ClassInfo_t* info, const char* method, const std::vector<TypeInfo_t*> &proto, bool objectIsConst, Long_t* Offset, ROOT::EFunctionMatchMode mode = ROOT::kConversionMatch) const { assert(false); }


   // ClassInfo interface
   virtual Bool_t ClassInfo_Contains(ClassInfo_t *info, DeclId_t decl) const;
   virtual ClassInfo_t  *ClassInfo_Factory(Bool_t /*all*/ = kTRUE) const;
   virtual ClassInfo_t  *ClassInfo_Factory(ClassInfo_t * /* cl */) const;
   virtual ClassInfo_t  *ClassInfo_Factory(const char * /* name */) const;

   virtual ClassInfo_t *BaseClassInfo_ClassInfo(BaseClassInfo_t * /* bcinfo */) const;

   virtual Long_t ClassInfo_ClassProperty(ClassInfo_t * /* info */) const;
   virtual void   ClassInfo_Delete(ClassInfo_t * /* info */) const;
   virtual void   ClassInfo_Delete(ClassInfo_t * /* info */, void * /* arena */) const { assert(false); }
   virtual void   ClassInfo_DeleteArray(ClassInfo_t * /* info */, void * /* arena */, bool /* dtorOnly */) const { assert(false); }
   virtual void   ClassInfo_Destruct(ClassInfo_t * /* info */, void * /* arena */) const { assert(false); }
   virtual Long_t   ClassInfo_GetBaseOffset(ClassInfo_t* /* fromDerived */,
                                            ClassInfo_t* /* toBase */, void* /* address */ = 0, bool /*isderived*/ = true) const;
   virtual int    ClassInfo_GetMethodNArg(ClassInfo_t * /* info */, const char * /* method */,const char * /* proto */, Bool_t /* objectIsConst */ = false, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) const { assert(false); }
   virtual Bool_t ClassInfo_HasDefaultConstructor(ClassInfo_t * /* info */) const { assert(false); }
   virtual Bool_t ClassInfo_HasMethod(ClassInfo_t * /* info */, const char * /* name */) const {assert(false);}
   virtual void   ClassInfo_Init(ClassInfo_t * /* info */, const char * /* funcname */) const {assert(false);}
   virtual void   ClassInfo_Init(ClassInfo_t * /* info */, int /* tagnum */) const {;}
   virtual Bool_t ClassInfo_IsBase(ClassInfo_t * /* info */, const char * /* name */) const {assert(false);}
   virtual Bool_t ClassInfo_IsEnum(const char * /* name */) const {assert(false);}
   virtual Bool_t ClassInfo_IsLoaded(ClassInfo_t * /* info */) const { return true;}
   virtual Bool_t ClassInfo_IsValid(ClassInfo_t * /* info */) const;
   virtual Bool_t ClassInfo_IsValidMethod(ClassInfo_t * /* info */, const char * /* method */,const char * /* proto */, Long_t * /* offset */, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) const {assert(false);}
   virtual Bool_t ClassInfo_IsValidMethod(ClassInfo_t * /* info */, const char * /* method */,const char * /* proto */, Bool_t /* objectIsConst */, Long_t * /* offset */, ROOT::EFunctionMatchMode /* mode */ = ROOT::kConversionMatch) const {assert(false);}
   virtual int    ClassInfo_Next(ClassInfo_t * /* info */) const {assert(false);}
   virtual void  *ClassInfo_New(ClassInfo_t * /* info */) const {assert(false);}
   virtual void  *ClassInfo_New(ClassInfo_t * /* info */, int /* n */) const {assert(false);}
   virtual void  *ClassInfo_New(ClassInfo_t * /* info */, int /* n */, void * /* arena */) const {assert(false);}
   virtual void  *ClassInfo_New(ClassInfo_t * /* info */, void * /* arena */) const {assert(false);}
   virtual Long_t ClassInfo_Property(ClassInfo_t * /* info */) const;
   virtual int    ClassInfo_Size(ClassInfo_t * /* info */) const;
   virtual Long_t ClassInfo_Tagnum(ClassInfo_t * /* info */) const {assert(false);}
   virtual const char *ClassInfo_FileName(ClassInfo_t * /* info */) const;
   virtual const char *ClassInfo_FullName(ClassInfo_t * /* info */) const;
   virtual const char *ClassInfo_Name(ClassInfo_t * /* info */) const;
   virtual const char *ClassInfo_Title(ClassInfo_t * /* info */) const;
   virtual const char *ClassInfo_TmpltName(ClassInfo_t * /* info */) const;

   // BaseClassInfo Interface
   virtual void   BaseClassInfo_Delete(BaseClassInfo_t * /* bcinfo */) const { assert(false); }
   virtual BaseClassInfo_t  *BaseClassInfo_Factory(ClassInfo_t * /* info */) const { assert(false); }
   virtual BaseClassInfo_t  *BaseClassInfo_Factory(ClassInfo_t* /* derived */,
                                                   ClassInfo_t* /* base */) const { assert(false); }
   virtual int    BaseClassInfo_Next(BaseClassInfo_t * /* bcinfo */) const { assert(false); }
   virtual int    BaseClassInfo_Next(BaseClassInfo_t * /* bcinfo */, int  /* onlyDirect */) const { assert(false); }
   virtual Long_t BaseClassInfo_Offset(BaseClassInfo_t * /* toBaseClassInfo */, void* /* address */ = 0 /*default for non-virtual*/, bool /*isderived*/ = true /*default for non-virtual*/) const;
   virtual Long_t BaseClassInfo_Property(BaseClassInfo_t * /* bcinfo */) const;
   virtual Long_t BaseClassInfo_Tagnum(BaseClassInfo_t * /* bcinfo */) const { assert(false); }
   virtual const char *BaseClassInfo_FullName(BaseClassInfo_t * /* bcinfo */) const;
   virtual const char *BaseClassInfo_Name(BaseClassInfo_t * /* bcinfo */) const { assert(false); }
   virtual const char *BaseClassInfo_TmpltName(BaseClassInfo_t * /* bcinfo */) const;


   // Function Template interface
   virtual void   FuncTempInfo_Delete(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual FuncTempInfo_t  *FuncTempInfo_Factory(DeclId_t declid) const { assert(false); }
   virtual FuncTempInfo_t  *FuncTempInfo_FactoryCopy(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual Bool_t FuncTempInfo_IsValid(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual UInt_t FuncTempInfo_TemplateNargs(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual UInt_t FuncTempInfo_TemplateMinReqArgs(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual Long_t FuncTempInfo_Property(FuncTempInfo_t * /* ft_info */) const { assert(false); }
   virtual void FuncTempInfo_Name(FuncTempInfo_t * /* ft_info */, TString &name) const { assert(false); }
   virtual void FuncTempInfo_Title(FuncTempInfo_t * /* ft_info */, TString &title) const { assert(false); }

   // MethodInfo interface
   virtual MethodInfo_t  *MethodInfo_Factory(DeclId_t declid) const;
   virtual Long_t MethodInfo_Property(MethodInfo_t * /* minfo */) const;
   virtual int    MethodInfo_NArg(MethodInfo_t * /* minfo */) const;
   virtual int    MethodInfo_NDefaultArg(MethodInfo_t * /* minfo */) const;
   virtual Long_t MethodInfo_ExtraProperty(MethodInfo_t * /* minfo */) const { assert(false); }
   virtual EReturnType MethodInfo_MethodCallReturnType(MethodInfo_t* minfo) const { assert(false); }

   // MethodArgInfo interface
   virtual std::string MethodArgInfo_TypeNormalizedName(MethodArgInfo_t * /* marginfo */) const { assert(false); }

   // DataMemberInfo interface
   virtual DataMemberInfo_t  *DataMemberInfo_Factory(DeclId_t declid, ClassInfo_t* clinfo) const;
   virtual int    DataMemberInfo_ArrayDim(DataMemberInfo_t * /* dminfo */) const;
   virtual void   DataMemberInfo_Delete(DataMemberInfo_t * /* dminfo */) const { assert(false); }
   virtual DataMemberInfo_t  *DataMemberInfo_Factory(ClassInfo_t * /* clinfo */ = 0) const { assert(false); }
   virtual DataMemberInfo_t  *DataMemberInfo_FactoryCopy(DataMemberInfo_t * /* dminfo */) const { assert(false); }
   virtual Bool_t DataMemberInfo_IsValid(DataMemberInfo_t * /* dminfo */) const;
   virtual int    DataMemberInfo_MaxIndex(DataMemberInfo_t * /* dminfo */, Int_t  /* dim */) const;
   virtual int    DataMemberInfo_Next(DataMemberInfo_t * /* dminfo */) const { assert(false); }
   virtual Long_t DataMemberInfo_Offset(DataMemberInfo_t * /* dminfo */) const { assert(false); }
   virtual Long_t DataMemberInfo_Property(DataMemberInfo_t * /* dminfo */) const;
   virtual Long_t DataMemberInfo_TypeProperty(DataMemberInfo_t * /* dminfo */) const;
   virtual int    DataMemberInfo_TypeSize(DataMemberInfo_t * /* dminfo */) const { assert(false); }
   virtual const char *DataMemberInfo_TypeName(DataMemberInfo_t * /* dminfo */) const;
   virtual const char *DataMemberInfo_TypeTrueName(DataMemberInfo_t * /* dminfo */) const;
   virtual const char *DataMemberInfo_Name(DataMemberInfo_t * /* dminfo */) const;
   virtual const char *DataMemberInfo_Title(DataMemberInfo_t * /* dminfo */) const;
   virtual const char *DataMemberInfo_ValidArrayIndex(DataMemberInfo_t * /* dminfo */) const { assert(false); }
};

TCxx::~TCxx() {}

#endif
