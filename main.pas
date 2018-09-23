unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    BRun: TButton;
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure BRunClick(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

  Point = record
    x, y, z: Int8;
  end;

  Piece = class
  private
  public
    sz: UInt8; // number of cubes in piece
    c: Array of Point; // the coordinates
    multi: Boolean; // allow copies of piece if true;
    index: UInt8;

    constructor Create(n: UInt8; m: Boolean; idx: UInt8); overload;
    constructor Create(var p: array of Point; m: Boolean; idx: UInt8); overload;
    procedure rotateX4;
    procedure rotateZ2;
    procedure rotateXYZ;
    procedure translatePiece(pc: Piece; x, y, z: Integer);
    procedure moveToOrigin;
    function toString: String;
    function maxCoord: Point;
  end;

  BigInteger = class
  private
  public
    sz: UInt8;
    d: array of UINT64;
    constructor Create(n: UInt8);
    function equalQ(b: BigInteger): Boolean;
    function disjunctQ(b: BigInteger): Boolean;
  end;

const
  // ********program coded constants, need to be set  before compiling *******

  NX = 5; // dimensions of the box
  NY = 5;
  NZ = 5;
  N_P = 2; // number of used pieces (1..8)

  // the coordinates of up to 8 pieces, here example with two pieces
  //X-Pentomino
  p0: Array [0 .. 4] of Point = ((x: 1; y: 0; z: 0), (x: 0; y: 1; z: 0), (x: 1;
    y: 1; z: 0), (x: 2; y: 1; z: 0), (x: 1; y: 2; z: 0));
  //K-Pentacube
  p1: Array [0 .. 4] of Point = ((x: 0; y: 0; z: 0), (x: 1; y: 0; z: 0), (x: 2;
    y: 0; z: 0), (x: 0; y: 0; z: 1), (x: 0; y: 1; z: 0));

  // not used in this example
  p2: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));
  p3: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));
  p4: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));
  p5: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));
  p6: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));
  p7: Array [0 .. 0] of Point = ((x: 0; y: 0; z: 0));

  // set true if piece is allowed to be used several times. SAT approach does
  // not scale well if set to false.
  multi: Array [0 .. 7] of Boolean = (true, true, true, true, true, true,
    true, true);
  // **********************end program coded constants **************************

  N_BIG = (NX * NY * NZ - 1) div 64 + 1;

var
  Form1: TForm1;
  piecePos: Array of Piece; // stores all possible positions of all pieces

  pieceHash, pieceHashRep: Array of BigInteger; // for the hashes of  piecePos

  piecePosIdxOfPoint: array of array of UInt16;
  piecePosIdxOfPointMx: array of Int16;
  varName: Array of Array of Integer;

  varnameToPiecePosIdx: Array of Integer;
  clauses: TSTringList;
  n_clauses, n_var: Integer;
  pcnt: Integer;
  maxSize, minSize: Integer;

implementation

uses console, StrUtils, Math;
{$R *.dfm}

constructor BigInteger.Create(n: UInt8);
var
  i: Integer;
begin
  sz := n;
  SetLength(d, sz);
  for i := 0 to sz - 1 do
    d[i] := 0;
end;

// CHeck if two BigInteger have at least one common bits
function BigInteger.disjunctQ(b: BigInteger): Boolean;
var
  i: Integer;
begin
  for i := 0 to sz - 1 do
    if (d[i] and b.d[i]) <> 0 then
      Exit(false);
  Exit(true);
end;

function BigInteger.equalQ(b: BigInteger): Boolean;
var
  i: Integer;
begin
  i := sz;
  for i := 0 to sz - 1 do
    if d[i] <> b.d[i] then
      Exit(false);
  result := true;
end;

constructor Piece.Create(n: UInt8; m: Boolean; idx: UInt8);
begin
  sz := n;
  multi := m;
  index := idx;
  SetLength(c, sz);
end;

constructor Piece.Create(var p: array of Point; m: Boolean; idx: UInt8);
var
  i: Integer;
begin
  sz := Length(p);
  multi := m;
  index := idx;
  SetLength(c, sz);
  for i := 0 to sz - 1 do
    c[i] := p[i];

end;

procedure Piece.translatePiece(pc: Piece; x, y, z: Integer);
var
  i: Integer;
begin
  for i := 0 to sz - 1 do
  begin
    c[i].x := pc.c[i].x + x;
    c[i].y := pc.c[i].y + y;
    c[i].z := pc.c[i].z + z;
  end;
end;

function Piece.maxCoord: Point;
var
  i: Integer;
begin
  result.x := -128;
  result.y := -128;
  result.z := -128;
  for i := 0 to sz - 1 do
  begin
    if c[i].x > result.x then
      result.x := c[i].x;
    if c[i].y > result.y then
      result.y := c[i].y;
    if c[i].z > result.z then
      result.z := c[i].z;
  end;
end;

procedure Piece.moveToOrigin;
var
  i, minx, miny, minz: Integer;
begin
  minx := MAXINT;
  miny := MAXINT;
  minz := MAXINT;
  for i := 0 to sz - 1 do
  begin
    if c[i].x < minx then
      minx := c[i].x;
    if c[i].y < miny then
      miny := c[i].y;
    if c[i].z < minz then
      minz := c[i].z;
  end;
  for i := 0 to sz - 1 do
  begin
    Dec(c[i].x, minx);
    Dec(c[i].y, miny);
    Dec(c[i].z, minz);
  end;
end;

function Piece.toString: String;
var
  s: String;
  pt: Point;
  i: Integer;
begin
  s := '{';
  for i := 0 to sz - 1 do
  begin
    pt := c[i];
    s := s + '{' + IntToStr(pt.x) + ',' + IntToStr(pt.y) + ',' +
      IntToStr(pt.z) + '}';
    if i <> sz - 1 then
      s := s + ','
    else
      s := s + '}'
  end;
  result := s;
end;

procedure Piece.rotateX4;
var
  i, tmp: Integer;
begin
  begin
    for i := 0 to sz - 1 do
    begin

      tmp := c[i].y;
      c[i].y := -c[i].z;
      c[i].z := tmp;
    end;
  end;
  moveToOrigin;
end;

procedure Piece.rotateXYZ;
var
  i, tmp: Integer;
begin
  for i := 0 to sz - 1 do
  begin
    tmp := c[i].x;
    c[i].x := c[i].y;
    c[i].y := c[i].z;
    c[i].z := tmp;
  end;
end;

procedure Piece.rotateZ2;
var
  i: Integer;
begin
  for i := 0 to sz - 1 do
  begin
    c[i].x := -c[i].x;
    c[i].y := -c[i].y;
    c[i].z := c[i].z;
  end;
  moveToOrigin;
end;

function pointHash(pt: Point): Integer;
begin
  result := pt.x;
  result := result * NY;
  Inc(result, pt.y);
  result := result * NZ;
  Inc(result, pt.z)
end;

function invPointHash(n: Integer): Point;
begin
  result.z := n mod NZ;
  n := n div NZ;
  result.y := n mod NY;
  result.x := n div NY;
end;

procedure setPiecePosHash(var p: Piece; var h: BigInteger);
var
  i, ps, base, offset: Integer;
begin
  for i := 0 to p.sz - 1 do
  begin
    ps := pointHash(p.c[i]);
    base := ps div 64;
    offset := ps mod 64;
    h.d[base] := h.d[base] or (UINT64(1) shl offset);
  end;

end;

function intersectQ(n1, n2: Integer): Boolean;
var
  pidx1, pidx2: Integer;
begin
  pidx1 := varnameToPiecePosIdx[n1];
  pidx2 := varnameToPiecePosIdx[n2];

  if pieceHash[pidx1].equalQ(pieceHash[pidx2]) and
    (piecePos[pidx1].index = piecePos[pidx2].index) then
    // Identical pieces in same position do not collide
    Exit(false);

  if pieceHash[pidx1].disjunctQ(pieceHash[pidx2]) then
  begin
    if piecePos[pidx1].index <> piecePos[pidx2].index then
      // different pieces in different positions do not collide
      Exit(false)
    else
      // identical pieces in different positions do not collide if copies are allowed
      if piecePos[pidx1].multi = true then
        Exit(false);
  end;
  // else collision
  result := true;
end;

function custom_split(input: string): TArray<string>;
var
  delimiterSet: array [0 .. 0] of char;
  // split works with char array, not a single char
begin
  delimiterSet[0] := ' '; // some character
  result := input.Split(delimiterSet);
end;

procedure TForm1.BRunClick(Sender: TObject);
var
  i, n, cnt: Integer;
  s, solution_raw, negated: String;
  output, errors: TSTringList;
  solution_split: TArray<String>;
  used: array of Boolean;
begin
  SetLength(used, pcnt);
  errors := TSTringList.Create;
  output := TSTringList.Create;
  cnt := 0;
  repeat
    GetConsoleOutput('java.exe -server  -jar org.sat4j.core.jar cnf.txt',
      output, errors);

    solution_raw := '';
    for i := 0 to output.Count - 1 do
    begin
      s := output.Strings[i];
      if s[1] = 's' then
      begin
        if ContainsText(s, 'UNSATISFIABLE') then
        begin
          Memo1.Lines.Add('No more solutions');
          Exit;
        end;
      end;

      if (s[1] = 'c') and ContainsText(s, 'Total wall clock time') then
        Memo1.Lines.Add(copy(s, 3, Length(s)));

      if s[1] = 'v' then
        solution_raw := solution_raw + copy(s, 3, Length(s));
    end;
    solution_split := custom_split(solution_raw);
    s := '';
    negated := '';
    for i := 0 to pcnt - 1 do
      used[i] := false;

    // Memo1.Lines.Add(IntToStr(cnt + 1));
    Memo1.Lines.Add('{');
    for i := 0 to Length(solution_split) - 1 do
      try
        n := StrToInt(solution_split[i]);
        if n > 0 then
        begin
          if not used[varnameToPiecePosIdx[n]] then
          begin
            used[varnameToPiecePosIdx[n]] := true;

            Memo1.Lines.Add(piecePos[varnameToPiecePosIdx[n]].toString + ',');
          end;
          negated := negated + '-' + IntToStr(n) + ' ';
        end;
      except
        on EConvertError do
      end;

    Memo1.Lines.Add('}');
    Memo1.Lines.Add('');
    negated := negated + '0';
    Application.ProcessMessages;

    clauses.Add(negated);
    Inc(n_clauses);
    clauses.Strings[1] := 'p cnf ' + IntToStr(n_var) + ' ' +
      IntToStr(n_clauses);
    clauses.SaveToFile('cnf.txt');
    Inc(cnt);
    Memo1.Lines.SaveToFile('solutions.txt'); // update solution file
    //the output can be viewed with the provided Mathematica file
  until true;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i, j, k, base, offset, n, idx: Integer;
  pc: Array of Piece;
  p, mx: Point;
  s1, s2, s3, ps: Integer;
  s: String;
  pDyn: array of Point;
  h: BigInteger;
  doublette: Boolean;

begin
  SetLength(pc, 8);
  SetLength(pDyn, Length(p0));
  Move(p0[Low(p0)], pDyn[0], SizeOf(p0));
  pc[0] := Piece.Create(pDyn, multi[0], 0);

  SetLength(pDyn, Length(p1));
  Move(p1[Low(p1)], pDyn[0], SizeOf(p1));
  pc[1] := Piece.Create(pDyn, multi[1], 1);

  SetLength(pDyn, Length(p2));
  Move(p2[Low(p2)], pDyn[0], SizeOf(p2));
  pc[2] := Piece.Create(pDyn, multi[2], 2);

  SetLength(pDyn, Length(p3));
  Move(p3[Low(p3)], pDyn[0], SizeOf(p3));
  pc[3] := Piece.Create(pDyn, multi[3], 3);

  SetLength(pDyn, Length(p4));
  Move(p4[Low(p4)], pDyn[0], SizeOf(p4));
  pc[4] := Piece.Create(pDyn, multi[4], 4);

  SetLength(pDyn, Length(p5));
  Move(p5[Low(p5)], pDyn[0], SizeOf(p5));
  pc[5] := Piece.Create(pDyn, multi[5], 5);

  SetLength(pDyn, Length(p6));
  Move(p6[Low(p6)], pDyn[0], SizeOf(p6));
  pc[6] := Piece.Create(pDyn, multi[6], 6);

  SetLength(pDyn, Length(p7));
  Move(p7[Low(p7)], pDyn[0], SizeOf(p7));
  pc[7] := Piece.Create(pDyn, multi[7], 7);

  maxSize := pc[0].sz;
  minSize := pc[0].sz;

  for i := 1 to N_P - 1 do
  begin
    maxSize := Max(maxSize, pc[i].sz);
    minSize := Min(minSize, pc[i].sz);
  end;

  SetLength(piecePos, NX * NY * NZ * 24 * N_P);
  SetLength(piecePosIdxOfPoint, NX * NY * NZ, 24 * maxSize * N_P);
  SetLength(piecePosIdxOfPointMx, NX * NY * NZ);
  SetLength(varName, NX * NY * NZ, 24 * maxSize * N_P);
  SetLength(varnameToPiecePosIdx, NX * NY * NZ * 24 * maxSize * N_P);
  SetLength(pieceHashRep, 24);

  pcnt := 0;
  for n := 0 to N_P - 1 do
  begin
    idx := 0;
    for i := 0 to 23 do
      pieceHashRep[i] := BigInteger.Create(N_BIG);
    for s1 := 0 to 2 do
    begin
      pc[n].rotateXYZ;
      for s2 := 0 to 1 do
      begin
        pc[n].rotateZ2;
        for s3 := 0 to 3 do
        begin
          pc[n].rotateX4;
          mx := pc[n].maxCoord;
          if (mx.x >= NX) or (mx.y >= NY) or (mx.z >= NZ) then
            continue; // piece does not fit into the box

          setPiecePosHash(pc[n], pieceHashRep[idx]);
          Inc(idx);
          doublette := false; // prevent doubles for symmetric pieces
          for k := 0 to idx - 2 do
            if pieceHashRep[idx - 1].equalQ(pieceHashRep[k]) then
            begin
              doublette := true;
              break;
            end;
          if doublette then
            continue;

          mx := pc[n].maxCoord;
          for i := 0 to NX - mx.x - 1 do
            for j := 0 to NY - mx.y - 1 do
              for k := 0 to NZ - mx.z - 1 do
              begin
                piecePos[pcnt] := Piece.Create(pc[n].sz, multi[n], n);
                piecePos[pcnt].translatePiece(pc[n], i, j, k);
                Inc(pcnt);
              end;
        end;
      end;
    end;
  end;

  SetLength(pieceHash, pcnt);
  // Number of necessary UInt64 numbers
  for i := 0 to pcnt - 1 do
    pieceHash[i] := BigInteger.Create(N_BIG);

  for i := 0 to pcnt - 1 do // set hashes for pieces
    setPiecePosHash(piecePos[i], pieceHash[i]);

  for i := 0 to NX * NY * NZ - 1 do
    piecePosIdxOfPointMx[i] := -1;

  // for each point p add the piece positions which use p
  for j := 0 to pcnt - 1 do
    for k := 0 to piecePos[j].sz - 1 do
    begin
      i := pointHash(piecePos[j].c[k]); // get k.th point of piecePos[j]
      Inc(piecePosIdxOfPointMx[i]);
      piecePosIdxOfPoint[i, piecePosIdxOfPointMx[i]] := j;
    end;

  for i := 0 to NX * NY * NZ - 1 do
    for j := 0 to 24 * maxSize * N_P - 1 do
      varName[i, j] := -1;
  n_var := 0;
  for i := 0 to NX * NY * NZ - 1 do
  begin
    for j := 0 to piecePosIdxOfPointMx[i] do
    begin
      Inc(n_var);
      varName[i, j] := n_var;
      // varname for point with hash i and the j. possible piece position
      varnameToPiecePosIdx[n_var] := piecePosIdxOfPoint[i, j];
    end;
  end;

  clauses := TSTringList.Create;
  n_clauses := 0;
  clauses.Add('c CNF file in DIMACS format');
  clauses.Add('dummy');

  // for each position at least one of the possible pieces is set
  for i := 0 to NX * NY * NZ - 1 do
  begin
    s := '';
    for j := 0 to piecePosIdxOfPointMx[i] do
      s := s + IntToStr(varName[i, j]) + ' ';
    clauses.Add(s + '0');
    Inc(n_clauses);
  end;

  for i := 1 to n_var - 1 do
  begin
    for j := i + 1 to n_var do
      if intersectQ(i, j) then
      begin
        clauses.Add('-' + IntToStr(i) + ' -' + IntToStr(j) + ' 0');
        Inc(n_clauses);
      end;
  end;

  clauses.Strings[1] := 'p cnf ' + IntToStr(n_var) + ' ' + IntToStr(n_clauses);
  clauses.SaveToFile('cnf.txt'); // Initial cnf file

end;

end.
