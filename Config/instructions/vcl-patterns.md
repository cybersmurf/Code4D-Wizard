# VCL (Visual Component Library) Patterns

## Component Ownership
```pascal
// ✅ Owner frees children automatically
var Panel := TPanel.Create(Self);   // form owns panel
Panel.Parent := Self;

var Button := TButton.Create(Panel); // panel owns button
Button.Parent := Panel;
// Both freed automatically when form closes

// ✅ Manually owned: use nil owner + free explicitly
var Dlg := TOpenDialog.Create(nil);
try
  if Dlg.Execute then
    Process(Dlg.FileName);
finally
  Dlg.Free;
end;
```

## Event Handlers
```pascal
// ✅ Check sender type before cast
procedure TForm1.ButtonClick(Sender: TObject);
begin
  if Sender is TButton then
    ShowMessage((Sender as TButton).Caption);
end;

// ✅ Use Tag for lightweight data binding
Button1.Tag := CustomerID;
procedure TForm1.EditButtonClick(Sender: TObject);
begin
  EditCustomer((Sender as TButton).Tag);
end;
```

## Actions (TAction / TActionList)
```pascal
// ✅ Centralise command logic in TAction — wired to menu + toolbar automatically
procedure TForm1.actSaveExecute(Sender: TObject);
begin
  Save;
end;

procedure TForm1.actSaveUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := FDirty;
end;
```

## Data-Aware Controls
```pascal
// ✅ Link components declaratively
DataSource1.DataSet := FDM.qryCustomers;
DBEdit1.DataSource  := DataSource1;
DBEdit1.DataField   := 'CustomerName';

// ✅ Edit / Post pattern
FDM.qryCustomers.Edit;
FDM.qryCustomers.FieldByName('Name').AsString := edtName.Text;
FDM.qryCustomers.Post;
```

## Threading in VCL
```pascal
// ✅ Background work + UI update
TTask.Run(procedure
begin
  var Result := DoHeavyWork;
  TThread.Synchronize(nil, procedure
  begin
    lblResult.Caption := Result;
  end);
end);

// ✅ Show wait cursor
Screen.Cursor := crHourGlass;
try
  DoLongOperation;
finally
  Screen.Cursor := crDefault;
end;
```

## Best Practices
- Use `TAction` for all menu/toolbar commands — never write logic directly in `OnClick`
- Disable controls during long operations (`pnlMain.Enabled := False`)
- Show `crHourGlass` for operations taking > 1 second
- Keep `FormCreate` fast — defer heavy init to `FormShow` or background thread
- Free dynamically created forms; set pointer to `nil` afterwards
- Use resource strings (`resourcestring`) for all user-visible text (localisation)
- Avoid `Application.ProcessMessages` in loops — use threads instead
