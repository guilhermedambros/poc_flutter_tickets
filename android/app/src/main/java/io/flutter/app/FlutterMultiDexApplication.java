package io.flutter.app;

import android.app.Application;
import androidx.multidex.MultiDex;
import android.content.Context;

public class FlutterMultiDexApplication extends Application {
  @Override
  protected void attachBaseContext(Context base) {
    super.attachBaseContext(base);
    MultiDex.install(this);
  }
}
