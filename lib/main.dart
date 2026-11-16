
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.i.db;
  try {
    await SupabaseConfig.initialize().timeout(
      const Duration(seconds: 12),
    );
    print('Supabase conectado.');
  } catch (e) {
    print('Supabase indisponível. Aplicativo continuará offline: $e');
  }
  runApp(const DonaVeraApp());
}

final brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final df = DateFormat('dd/MM/yyyy');

class DB {
  DB._();
  static final i = DB._();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'dona_vera.db');
    _db = await openDatabase(path, version: 1, onConfigure: (d) async {
      await d.execute('PRAGMA foreign_keys=ON');
    }, onCreate: (d, v) async {
      await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,cost REAL NOT NULL,price REAL NOT NULL,stock REAL NOT NULL DEFAULT 0)');
      await d.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT DEFAULT "")');
      await d.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER,total REAL NOT NULL,cost_total REAL NOT NULL,paid REAL NOT NULL DEFAULT 0,due_date TEXT,created_at TEXT NOT NULL,FOREIGN KEY(customer_id) REFERENCES customers(id))');
      await d.execute('CREATE TABLE sale_items(id INTEGER PRIMARY KEY AUTOINCREMENT,sale_id INTEGER NOT NULL,product_id INTEGER,product_name TEXT NOT NULL,quantity REAL NOT NULL,unit_price REAL NOT NULL,unit_cost REAL NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id))');
      await d.execute('CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT,sale_id INTEGER NOT NULL,amount REAL NOT NULL,created_at TEXT NOT NULL,FOREIGN KEY(sale_id) REFERENCES sales(id))');
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,description TEXT NOT NULL,amount REAL NOT NULL,created_at TEXT NOT NULL)');
    });
    return _db!;
  }
  Future<List<Map<String,Object?>>> list(String table, {String order='id DESC'}) async => (await db).query(table, orderBy: order);
  Future<int> add(String table, Map<String,Object?> data) async => (await db).insert(table,data);
  Future<void> sale({required int? customer, required Map<String,dynamic> product, required double qty, required double paid, DateTime? due}) async {
    final d = await db;
    await d.transaction((t) async {
      final total = (product['price'] as num).toDouble()*qty;
      final cost = (product['cost'] as num).toDouble()*qty;
      final id = await t.insert('sales', {'customer_id':customer,'total':total,'cost_total':cost,'paid':paid,'due_date':due?.toIso8601String(),'created_at':DateTime.now().toIso8601String()});
      await t.insert('sale_items', {'sale_id':id,'product_id':product['id'],'product_name':product['name'],'quantity':qty,'unit_price':product['price'],'unit_cost':product['cost']});
      await t.rawUpdate('UPDATE products SET stock=MAX(0,stock-?) WHERE id=?',[qty,product['id']]);
    });
  }
  Future<void> payment(int saleId,double amount) async {
    final d=await db;
    await d.transaction((t) async {
      await t.insert('payments',{'sale_id':saleId,'amount':amount,'created_at':DateTime.now().toIso8601String()});
      await t.rawUpdate('UPDATE sales SET paid=paid+? WHERE id=?',[amount,saleId]);
    });
  }
}

class DonaVeraApp extends StatelessWidget {
  const DonaVeraApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Bar e Armazém Dona Vera', debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF15965B)),scaffoldBackgroundColor:const Color(0xFFFFFAF0)),
    home:const MainPage(),
  );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override State<MainPage> createState()=>_MainPageState();
}
class _MainPageState extends State<MainPage> {
  int index=0, tick=0;
  void refresh(){setState(()=>tick++);}
  @override Widget build(BuildContext context){
    final pages=[
      Dashboard(key:ValueKey('d$tick')),
      Sales(key:ValueKey('s$tick'),changed:refresh),
      Customers(key:ValueKey('c$tick'),changed:refresh),
      Products(key:ValueKey('p$tick'),changed:refresh),
      Finance(key:ValueKey('f$tick')),
    ];
    return Scaffold(
      appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Bar e Armazém',style:TextStyle(fontWeight:FontWeight.w800)),
        Text('Dona Vera',style:TextStyle(fontSize:12)),
      ]),backgroundColor:const Color(0xFF15965B),foregroundColor:Colors.white,
      actions:[IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]),
      body:IndexedStack(index:index,children:pages),
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const[
        NavigationDestination(icon:Icon(Icons.home),label:'Início'),
        NavigationDestination(icon:Icon(Icons.point_of_sale),label:'Vendas'),
        NavigationDestination(icon:Icon(Icons.people),label:'Clientes'),
        NavigationDestination(icon:Icon(Icons.inventory_2),label:'Produtos'),
        NavigationDestination(icon:Icon(Icons.account_balance_wallet),label:'Financeiro'),
      ]),
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Future<Map<String,double>> getData() async {
    final d=await DB.i.db;
    final s=(await d.rawQuery('SELECT COALESCE(SUM(total),0) total,COALESCE(SUM(paid),0) paid,COALESCE(SUM(cost_total),0) cost FROM sales')).first;
    final e=(await d.rawQuery('SELECT COALESCE(SUM(amount),0) v FROM expenses')).first['v'] as num;
    return {'v':(s['total'] as num).toDouble(),'r':(s['paid'] as num).toDouble(),'f':((s['total'] as num)-(s['paid'] as num)).toDouble(),'l':((s['total'] as num)-(s['cost'] as num)-e).toDouble(),'e':e.toDouble()};
  }
  @override Widget build(BuildContext context)=>FutureBuilder(future:getData(),builder:(c,s){
    final x=s.data??{};
    double n(String k)=>x[k]??0;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF15965B),Color(0xFF64BD55)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Olá, Dona Vera! 🍻',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold)),
        SizedBox(height:5),Text('Seu armazém organizado e sob controle.',style:TextStyle(color:Colors.white)),
      ])),
      const SizedBox(height:18),const Text('Resumo financeiro',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      if(s.connectionState==ConnectionState.waiting) const Center(child:CircularProgressIndicator()) else
      Wrap(spacing:8,runSpacing:8,children:[
        metric('Vendido',n('v'),Icons.shopping_bag,Colors.blue),
        metric('Recebido',n('r'),Icons.payments,Colors.green),
        metric('Fiado aberto',n('f'),Icons.menu_book,Colors.deepOrange),
        metric('Lucro estimado',n('l'),Icons.trending_up,Colors.purple),
      ]),
      const SizedBox(height:8),Card(child:ListTile(leading:const Icon(Icons.receipt_long,color:Colors.deepOrange),title:const Text('Despesas registradas'),trailing:Text(brl.format(n('e')),style:const TextStyle(fontWeight:FontWeight.bold)))),
      const Padding(padding:EdgeInsets.only(top:12),child:Text('Cadastre o custo e o preço de venda dos produtos para calcular a margem. O lucro mostrado é uma estimativa acumulada, antes de ajustes de estoque e perdas.',style:TextStyle(color:Colors.black54))),
    ]);
  });
  Widget metric(String title,double value,IconData icon,Color color)=>SizedBox(width:MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).size.width/2-25,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color)),
    const SizedBox(height:8),Text(title,style:const TextStyle(color:Colors.black54,fontSize:12)),
    FittedBox(child:Text(brl.format(value),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
  ]))));
}

Future<String?> prompt(BuildContext c,String title,{String initial='',TextInputType type=TextInputType.text}) async {
  final ctl=TextEditingController(text:initial);
  return showDialog<String>(context:c,builder:(x)=>AlertDialog(title:Text(title),content:TextField(controller:ctl,keyboardType:type,autofocus:true,decoration:const InputDecoration(hintText:'Digite aqui')),actions:[
    TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancelar')),
    FilledButton(onPressed:()=>Navigator.pop(x,ctl.text.trim()),child:const Text('Salvar')),
  ]));
}
double numVal(String? s)=>double.tryParse((s??'').replaceAll(',','.'))??0;

class Products extends StatefulWidget {
  final VoidCallback changed; const Products({super.key,required this.changed});
  @override State<Products> createState()=>_ProductsState();
}
class _ProductsState extends State<Products>{
  Future<void> add() async {
    final name=await prompt(context,'Nome do produto'); if(!mounted||name==null||name.isEmpty)return;
    final cost=await prompt(context,'Custo de compra (R\$)',type:TextInputType.number);if(!mounted||cost==null)return;
    final price=await prompt(context,'Preço de venda (R\$)',type:TextInputType.number);if(!mounted||price==null)return;
    final stock=await prompt(context,'Estoque inicial',initial:'0',type:TextInputType.number);if(!mounted)return;
    await DB.i.add('products',{'name':name,'cost':numVal(cost),'price':numVal(price),'stock':numVal(stock)});
    setState((){});widget.changed();
  }
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Produto')),body:FutureBuilder(future:DB.i.list('products',order:'name COLLATE NOCASE'),builder:(c,s){
    final rows=s.data??[];
    if(rows.isEmpty)return const Empty(icon:Icons.inventory_2,title:'Nenhum produto cadastrado',sub:'Toque em Produto para começar.');
    return ListView(padding:const EdgeInsets.all(10),children:rows.map((r)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.local_drink)),title:Text('${r['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('Custo ${brl.format(r['cost'])} • Estoque ${r['stock']}'),trailing:Text(brl.format(r['price']),style:const TextStyle(color:Color(0xFF15965B),fontWeight:FontWeight.bold))))).toList());
  }));
}

class Customers extends StatefulWidget {
  final VoidCallback changed; const Customers({super.key,required this.changed});
  @override State<Customers> createState()=>_CustomersState();
}
class _CustomersState extends State<Customers>{
  Future<void> add() async {
    final name=await prompt(context,'Nome do cliente');if(!mounted||name==null||name.isEmpty)return;
    final phone=await prompt(context,'Telefone (opcional)')??'';
    await DB.i.add('customers',{'name':name,'phone':phone});setState((){});widget.changed();
  }
  Future<double> debt(int id) async {final d=await DB.i.db;final r=(await d.rawQuery('SELECT COALESCE(SUM(total-paid),0) v FROM sales WHERE customer_id=?',[id])).first['v'] as num;return r.toDouble();}
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.person_add),label:const Text('Cliente')),body:FutureBuilder(future:DB.i.list('customers',order:'name COLLATE NOCASE'),builder:(c,s){
    final rows=s.data??[];if(rows.isEmpty)return const Empty(icon:Icons.people,title:'Nenhum cliente cadastrado',sub:'Cadastre os clientes que compram no fiado.');
    return ListView(padding:const EdgeInsets.all(10),children:rows.map((r)=>FutureBuilder<double>(future:debt(r['id'] as int),builder:(c,d)=>Card(child:ListTile(leading:CircleAvatar(child:Text('${r['name']}'.substring(0,1).toUpperCase())),title:Text('${r['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${r['phone']??''}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[const Text('Em aberto',style:TextStyle(fontSize:11)),Text(brl.format(d.data??0),style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold))]))))).toList());
  }));
}

class Sales extends StatefulWidget {
  final VoidCallback changed; const Sales({super.key,required this.changed});
  @override State<Sales> createState()=>_SalesState();
}
class _SalesState extends State<Sales>{
  Future<void> addSale() async {
    final products=await DB.i.list('products',order:'name');final customers=await DB.i.list('customers',order:'name');
    if(!mounted)return;if(products.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cadastre um produto primeiro.')));return;}
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>SaleDialog(products:products,customers:customers));
    if(!mounted||result==null)return;
    await DB.i.sale(customer:result['customer'],product:result['product'],qty:result['qty'],paid:result['paid'],due:result['due']);
    setState((){});widget.changed();
  }
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:addSale,icon:const Icon(Icons.add_shopping_cart),label:const Text('Nova venda')),body:FutureBuilder(future:DB.i.list('sales'),builder:(c,s){
    final rows=s.data??[];if(rows.isEmpty)return const Empty(icon:Icons.point_of_sale,title:'Nenhuma venda ainda',sub:'Registre a primeira venda do armazém.');
    return ListView(padding:const EdgeInsets.all(10),children:rows.map((r){final balance=(r['total'] as num)-(r['paid'] as num);return Card(child:ListTile(leading:CircleAvatar(child:Icon(balance>0?Icons.menu_book:Icons.check,color:balance>0?Colors.deepOrange:Colors.green)),title:Text('Venda #${r['id']} • ${brl.format(r['total'])}'),subtitle:Text('${df.format(DateTime.parse(r['created_at'] as String))} • ${balance>0?'Fiado':'Paga'}'),trailing:Text(balance>0?'Falta ${brl.format(balance)}':'Paga',style:TextStyle(color:balance>0?Colors.deepOrange:Colors.green,fontWeight:FontWeight.bold,fontSize:12))));}).toList());
  }));
}

class SaleDialog extends StatefulWidget {
  final List<Map<String,Object?>> products,customers;
  const SaleDialog({super.key,required this.products,required this.customers});
  @override State<SaleDialog> createState()=>_SaleDialogState();
}
class _SaleDialogState extends State<SaleDialog>{
  int? productId,customerId;double qty=1,paid=0;DateTime? due;
  @override Widget build(BuildContext c){
    final product=widget.products.where((x)=>x['id']==productId).firstOrNull;
    final total=product==null?0.0:(product['price'] as num).toDouble()*qty;
    return AlertDialog(title:const Text('Nova venda'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<int>(isExpanded:true,decoration:const InputDecoration(labelText:'Produto'),items:widget.products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} • ${brl.format(x['price'])}'))).toList(),onChanged:(v)=>setState(()=>productId=v)),
      const SizedBox(height:10),TextFormField(initialValue:'1',keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantidade'),onChanged:(v)=>setState(()=>qty=numVal(v).clamp(.01,100000).toDouble())),
      const SizedBox(height:10),DropdownButtonFormField<int?>(isExpanded:true,decoration:const InputDecoration(labelText:'Cliente (opcional)'),items:[const DropdownMenuItem<int?>(value:null,child:Text('Venda sem cliente')),...widget.customers.map((x)=>DropdownMenuItem<int?>(value:x['id'] as int,child:Text('${x['name']}')))],onChanged:(v)=>setState(()=>customerId=v)),
      const SizedBox(height:12),Text('Total: ${brl.format(total)}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      TextFormField(key:ValueKey(total),initialValue:total.toStringAsFixed(2),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Recebido agora (R\$)'),onChanged:(v)=>setState(()=>paid=numVal(v).clamp(0,total).toDouble())),
      if(paid<total)TextButton.icon(onPressed:()async{final d=await showDatePicker(context:c,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:3650)),initialDate:DateTime.now().add(const Duration(days:7)));if(d!=null)setState(()=>due=d);},icon:const Icon(Icons.calendar_month),label:Text(due==null?'Definir vencimento':'Vence ${df.format(due!)}')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),FilledButton(onPressed:product==null||total<=0?null:()=>Navigator.pop(c,{'product':product,'qty':qty,'customer':customerId,'paid':paid,'due':due}),child:const Text('Salvar venda'))]);
  }
}

class Finance extends StatefulWidget {const Finance({super.key});@override State<Finance> createState()=>_FinanceState();}
class _FinanceState extends State<Finance>{
  Future<void> expense()async{final desc=await prompt(context,'Descrição da despesa');if(!mounted||desc==null||desc.isEmpty)return;final v=await prompt(context,'Valor (R\$)',type:TextInputType.number);if(!mounted||v==null||numVal(v)<=0)return;await DB.i.add('expenses',{'description':desc,'amount':numVal(v),'created_at':DateTime.now().toIso8601String()});setState((){});}
  Future<void> receive(int id,double balance)async{final v=await prompt(context,'Valor recebido (saldo ${brl.format(balance)})',type:TextInputType.number);if(!mounted||v==null||numVal(v)<=0||numVal(v)>balance)return;await DB.i.payment(id,numVal(v));setState((){});}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(10),children:[
    Row(children:[const Expanded(child:Text('Contas a receber',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),FilledButton.tonalIcon(onPressed:expense,icon:const Icon(Icons.add),label:const Text('Despesa'))]),
    FutureBuilder(future:DB.i.list('sales'),builder:(c,s){final pending=(s.data??[]).where((r)=>(r['total'] as num)>(r['paid'] as num)).toList();if(pending.isEmpty)return const Padding(padding:EdgeInsets.all(18),child:Text('Nenhuma venda pendente.'));return Column(children:pending.map((r){final bal=(r['total'] as num).toDouble()-(r['paid'] as num).toDouble();final due=r['due_date']==null?'Sem vencimento':'Vence ${df.format(DateTime.parse(r['due_date'] as String))}';return Card(child:ListTile(title:Text('Venda #${r['id']} • ${brl.format(bal)}'),subtitle:Text(due),trailing:IconButton(icon:const Icon(Icons.payments,color:Color(0xFF15965B)),onPressed:()=>receive(r['id'] as int,bal))));}).toList());}),
    const SizedBox(height:14),const Text('Despesas',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
    FutureBuilder(
      future: DB.i.list('expenses'),
      builder: (c, s) {
        final rows = s.data ?? [];
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhuma despesa registrada.'),
          );
        }
        return Column(
          children: rows.map((r) => Card(
            child: ListTile(
              leading: const Icon(Icons.receipt, color: Colors.deepOrange),
              title: Text('${r['description']}'),
              subtitle: Text(df.format(DateTime.parse(r['created_at'] as String))),
              trailing: Text(brl.format(r['amount'])),
            ),
          )).toList(),
        );
      },
    ),
  ]);
}

class Empty extends StatelessWidget {
  final IconData icon;final String title,sub;
  const Empty({super.key,required this.icon,required this.title,required this.sub});
  @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    CircleAvatar(radius:38,backgroundColor:const Color(0xFFE2F4E9),child:Icon(icon,size:38,color:const Color(0xFF15965B))),
    const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
    const SizedBox(height:5),Text(sub,style:const TextStyle(color:Colors.black54),textAlign:TextAlign.center),
  ])));
}
