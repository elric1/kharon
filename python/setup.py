from distutils.core import setup,Extension
import os

incdir = os.path.normpath(os.path.join(os.path.dirname(__file__),"..","ArrayHash"))

setup(name='kharon',
      version='0.5',
      packages = ['kharon',],
      ext_modules=[
                   Extension('kharon.pyarrayhash', 
                             sources = ['pyarrayhash.c',],
                             include_dirs = [incdir,],
                             libraries = [])

	    ],

	)


