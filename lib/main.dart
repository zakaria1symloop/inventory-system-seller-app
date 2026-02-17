import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/add_client_screen.dart';
import 'presentation/screens/create_order_screen.dart';
import 'presentation/screens/order_detail_screen.dart';
import 'presentation/screens/caisse_screen.dart';
import 'data/models/order_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق البائع',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/add-client': (context) => const AddClientScreen(),
        '/create-order': (context) => const CreateOrderScreen(),
        '/caisse': (context) => const CaisseScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/order-detail') {
          final order = settings.arguments as OrderModel;
          return MaterialPageRoute(
            builder: (context) => OrderDetailScreen(
              orderId: order.id ?? 0,
              initialOrder: order,
            ),
          );
        }
        return null;
      },
    );
  }
}
