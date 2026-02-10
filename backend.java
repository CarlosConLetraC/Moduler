import java.io.*;
import java.nio.file.*;
import java.util.ArrayList;
import java.util.List;
import static java.lang.System.out;
import static java.lang.System.err;

abstract class Proceso implements Runnable {
    private static int nextPid = 1;
    private final int pid;

    protected Proceso() {
        this.pid = nextPid++;
    }

    public int getPid() {
        return pid;
    }
}

class lua_State extends Proceso {
    private final Path rutaDeScript;
    public lua_State(Path rutaDeScript) {
        super();
        this.rutaDeScript = rutaDeScript;
        out.printf("Iniciando instancia LuaJIT con PID=%d -> %s\n", getPid(), rutaDeScript.getFileName());
    }

    @Override
    public void run() {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                "./luajit", "-l", "import/init",
                "main.lua", rutaDeScript.toString()
            );

            pb.redirectErrorStream(true);
            Process p = pb.start();

            try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(p.getInputStream()))) {
                String line;
                List<String> packed = new ArrayList<>();
                while ((line = reader.readLine()) != null) packed.add(line);
                out.printf("[%s] PID=%d\n%s\n\n", rutaDeScript.toString(), getPid(), String.join("\n", packed));
            }

            int exitCode = p.waitFor();
            out.printf("PID=%d terminado con salida %d\n", getPid(), exitCode);

        } catch (IOException | InterruptedException e) {
            out.printf("PID=%d error: %s\n", getPid(), e.getMessage());
        }
    }
}

public class backend {
    public static void main(String[] args) throws IOException, InterruptedException {
        Path scriptsDir = Paths.get(".");
        List<Thread> threads = new ArrayList<>();

        try (DirectoryStream<Path> stream = Files.newDirectoryStream(scriptsDir, "program*.lua")) {
            for (Path script : stream) {
                lua_State luaTask = new lua_State(script);
                Thread t = new Thread(luaTask);
                t.start();
                threads.add(t);
            }
        }

        for (Thread t : threads) t.join();
        out.println("El backend de Java a terminado de procesar todos los hilos.");
    }
}
