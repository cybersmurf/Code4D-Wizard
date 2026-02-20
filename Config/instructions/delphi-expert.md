# Delphi Expert Context

## Language Version
- Target: **Delphi 12 Athens** (Studio 23.0), Win32/Win64
- Use modern syntax: `inline var`, nested types, anonymous methods, `TProc<T>`, `TFunc<T,R>`

## Key Libraries in Stack
| Library | Purpose |
|---------|---------|
| TMS Aurelius | ORM (entity mapping, LINQ, sessions) |
| TMS XData | REST-over-Aurelius service framework |
| TMS Sparkle | HTTP server middleware |
| TMS Business | Business object validation, events |
| madExcept | Exception tracking + stack traces |
| FastReport | Reporting engine |

## Aurelius ORM Patterns

### Entity Declaration
```pascal
[Entity, Automapping]
[Model('Default')]
[Table('TB_EMPLOYEE')]
TEmployee = class
private
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  FId: Integer;

  [Column('Name', [TColumnProp.Required])]
  FName: string;

  [Column('Created', [TColumnProp.Required])]
  FCreated: TDateTime;

  [Column('Deleted')]
  FDeleted: TNullableDateTime;  // soft-delete pattern

  [Association([TAssociationProp.Lazy], CascadeTypeAll)]
  [ForeignJoinColumn('FK_Dept_Id', [TColumnProp.Required])]
  FDepartment: TDepartment;
public
  property Id:          Integer            read FId          write FId;
  property Name:        string             read FName        write FName;
  property Created:     TDateTime          read FCreated     write FCreated;
  property Deleted:     TNullableDateTime  read FDeleted     write FDeleted;
  property Department:  TDepartment        read FDepartment  write FDepartment;
end;
```

### Session/Query Pattern
```pascal
var LManager := ObjectManager;
try
  var LEmployee := LManager.Find<TEmployee>(42);
  // LINQ query
  var LList := LManager.Find<TEmployee>
    .Where(TLinq.GreaterThan('Salary', 50000))
    .OrderBy('Name')
    .List;
finally
  // Manager owned by XData context – don't free here
end;
```

## XData Service Patterns

### Service Contract
```pascal
[ServiceContract]
IEmployeeService = interface
  ['{GUID}']
  [HttpGet]  [Route('api/employees')]
  function List: TObjectList<TEmployee>;

  [HttpGet]  [Route('api/employees/{id}')]
  function GetById(Id: Integer): TEmployee;

  [HttpPost] [Route('api/employees')]
  function Create([FromBody] AEmployee: TEmployee): TEmployee;

  [HttpPut]  [Route('api/employees/{id}')]
  function Update(Id: Integer; [FromBody] AEmployee: TEmployee): TEmployee;

  [HttpDelete][Route('api/employees/{id}')]
  procedure Delete(Id: Integer);
end;
```

## Naming Conventions
- Entity classes: `T{Domain}{Entity}` (e.g. `THREmployee`, `TInventoryItem`)
- Service interfaces: `I{Domain}{Entity}Service`
- Repository/Manager: `T{Domain}{Entity}Manager`
- DTOs: `T{Domain}{Entity}DTO`
- Events: `On{Entity}{Action}` (e.g. `OnEmployeeInserted`)

## Best Practices
- Use `TNullableDateTime` for optional timestamps (soft delete, end-date)
- Add `Modified: TNullableDateTime` and update on every save via `TManagerEvents`
- Always set `Lazy` loading on associations; eager-load only when needed
- Index FK columns and columns used in `WHERE` / `ORDER BY`
- Wrap bulk operations in explicit transactions: `LManager.Connection.StartTransaction`
