# MES Architecture

## System Overview
This project is a modular Manufacturing Execution System built on:
- **Backend**: TMS Aurelius (ORM) + TMS XData (REST API) + TMS Sparkle
- **Frontend**: Blazor Server / TMS Web Core
- **Database**: MariaDB / PostgreSQL
- **Architecture**: Plugin-module system with event-driven cross-module communication

## Core Modules
| Module | Prefix | Description |
|--------|--------|-------------|
| HR & Attendance | `THR` | Employee management, time tracking, shifts |
| Inventory | `TInv` | Material tracking, warehouse, BOM |
| Planning | `TPlan` | Production scheduling, capacity |
| Quality | `TQual` | Inspection, NCR, defect tracking |
| Stations | `TStn` | Terminal operations, work order execution |
| Maintenance | `TMaint` | Equipment, preventive maintenance |

## Standard Entity Pattern

```pascal
[Entity, Automapping]
[Model('Default')]
[Table('TB_{MODULE}_{ENTITY}')]
T{Module}{Entity} = class
private
  [Id('FId', TIdGenerator.IdentityOrSequence)]
  FId: Integer;

  [Column('Created',    [TColumnProp.Required])]  FCreated:    TDateTime;
  [Column('Modified')]                              FModified:   TNullableDateTime;
  [Column('Deleted')]                               FDeleted:    TNullableDateTime;
  [Column('CreatedBy',  [TColumnProp.Required])]   FCreatedBy:  string;
  [Column('ModifiedBy')]                            FModifiedBy: TNullableString;

  // optional: soft-reference to parent module
  [Association([TAssociationProp.Lazy], CascadeTypeAll)]
  [ForeignJoinColumn('FK_Parent_Id', [TColumnProp.Required])]
  FParent: TParentEntity;
public
  property Id:         Integer           read FId          write FId;
  property Created:    TDateTime         read FCreated     write FCreated;
  property Modified:   TNullableDateTime read FModified    write FModified;
  property Deleted:    TNullableDateTime read FDeleted     write FDeleted;
  property CreatedBy:  string            read FCreatedBy   write FCreatedBy;
  property ModifiedBy: TNullableString   read FModifiedBy  write FModifiedBy;
end;
```

## XData Service Pattern

```pascal
[ServiceContract]
T{Module}{Entity}Service = class
public
  [HttpGet, Route('api/{module}/{entity}')]
  function List: TObjectList<T{Module}{Entity}>;

  [HttpGet, Route('api/{module}/{entity}/{id}')]
  function GetById(Id: Integer): T{Module}{Entity};

  [HttpPost, Route('api/{module}/{entity}')]
  function Create([FromBody] Entity: T{Module}{Entity}): T{Module}{Entity};

  [HttpPut, Route('api/{module}/{entity}/{id}')]
  function Update(Id: Integer; [FromBody] Entity: T{Module}{Entity}): T{Module}{Entity};

  [HttpDelete, Route('api/{module}/{entity}/{id}')]
  procedure Delete(Id: Integer);
end;
```

## Cross-Module Communication
- Use **TMS Business EventBus** for loose coupling between modules
- Example: `EventBus.Publish(TInventoryReservedEvent.Create(ItemId, Quantity))`
- Each module has its own event types in `{Module}.Events.pas`
- Never call another module's service directly — go through events or a shared manager

## Audit Logging
- Hook `TManagerEvents.OnInserted`, `OnUpdated`, `OnDeleted` for automatic audit trails
- Call `TAuditManager.Log(Entity, Action, UserId)` in each hook

## Best Practices Checklist
When generating MES code:
- [ ] Entity name follows `T{Module}{Entity}` pattern
- [ ] Table name follows `TB_{MODULE}_{ENTITY}` pattern
- [ ] All four audit fields present (Created, Modified, Deleted, CreatedBy)
- [ ] FK columns have `[TColumnProp.Required]` where NOT NULL
- [ ] Associations use `[TAssociationProp.Lazy]`
- [ ] Service route follows `/api/{module-lower}/{entity-lower}`
- [ ] Soft-delete: set `Deleted` timestamp, never physical delete
- [ ] Validation implemented via `IValidatable` when business rules present
