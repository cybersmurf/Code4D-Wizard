# eMISTR — Manufacturing Execution System Context

## What is eMISTR?
eMISTR is the production execution layer built on top of FlexGrid that manages:
- **Work Orders** — production orders from ERP → shopfloor execution
- **Station Terminals** — operator touchscreens for order pickup, scanning, reporting
- **Quality Gates** — inline inspection at each production step
- **Traceability** — full genealogy from raw material to finished good

## Core eMISTR Entities

### Work Order
```pascal
// TeMISTRWorkOrder tracks a single production order across all stations
[Entity, Automapping]
[Table('TB_MES_WORK_ORDER')]
TeMISTRWorkOrder = class
  // FK to product / BOM
  // Status: Planned | Released | InProgress | Completed | Cancelled
  // Priority: Low | Normal | High | Urgent
end;
```

### Station Activity
```pascal
// Records every operator scan / action at a terminal
[Entity, Automapping]
[Table('TB_MES_STATION_ACTIVITY')]
TeMISTRStationActivity = class
  // FK WorkOrder, FK Station, FK Operator
  // ActionType: Start | Stop | Defect | Rework | Complete
  // Quantity: produced, scrap, rework
end;
```

## Key Business Rules
1. A Work Order must be **Released** before station pick-up
2. Only one operator can be **active** on a Work Order step at a time
3. Quality holds **block** downstream steps automatically
4. All scrap must reference a **Defect Code** (from TQCDefect)
5. Completed quantities must not exceed the **planned quantity**
6. Timestamps use UTC internally; display in local time

## REST API Conventions
- Base path: `/api/mes/`
- Work orders: `/api/mes/workorders`
- Station ops: `/api/mes/stations/{stationId}/activities`
- Quality: `/api/mes/quality/inspections`

## Integration Points
- **ERP sync**: Work orders imported via `TMESERPSyncService` (polling or webhook)
- **Label printing**: `TLabelPrintService.Print(WorkOrderId, LabelTemplateId)`
- **OEE calculation**: `TOEEService.Calculate(StationId, DateFrom, DateTo)`
- **Traceability**: `TTraceabilityService.GetGenealogy(SerialNumber)`

## Coding Notes for AI
- eMISTR entity prefix: `TeMISTR` (note lowercase e)
- Table prefix: `TB_MES_`
- Service route prefix: `/api/mes/`
- Always record `OperatorId`, `StationId`, `Timestamp` in station activities
- Use distributed locking pattern for concurrent station access to the same work order
